// Complete fingerprint payment system application.
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"
#include "sleep.h"

#ifndef XPAR_FP_PAYMENT_PERIPH_0_BASEADDR
#ifdef XPAR_FP_PERIPH_0_BASEADDR
#define XPAR_FP_PAYMENT_PERIPH_0_BASEADDR XPAR_FP_PERIPH_0_BASEADDR
#else
#error "fp_payment_periph base address not found in xparameters.h"
#endif
#endif

#define PERIPH_BASE  XPAR_FP_PAYMENT_PERIPH_0_BASEADDR

#define REG_FP_CMD   (PERIPH_BASE + 0x00)
#define REG_FP_RESP  (PERIPH_BASE + 0x04)
#define REG_KB_DATA  (PERIPH_BASE + 0x08)
#define REG_BUZZER   (PERIPH_BASE + 0x0C)
#define REG_VGA_CHAR (PERIPH_BASE + 0x10)
#define REG_LED      (PERIPH_BASE + 0x14)
#define REG_FP_DBG   (PERIPH_BASE + 0x18)

#define VGA_COLS 80
#define VGA_ROWS 30
#define MAX_ACCOUNTS 32

#define BEEP_SHORT 0x01
#define BEEP_OK    0x02
#define BEEP_FAIL  0x04

#define FP_GET_IMAGE      0x01
#define FP_GEN_CHAR       0x02
#define FP_SEARCH         0x04
#define FP_STORE_CHAR     0x06
#define FP_REG_MODEL      0x05
#define FP_VFY_PWD        0x13
#define FP_READ_SYS_PARA  0x0F
#define FP_VALID_TMPL_NUM 0x1D

typedef struct {
    u8  active;
    u16 template_id;
    u32 balance_cents;
    char name[16];
} account_t;

static account_t accounts[MAX_ACCOUNTS] = {
    {1, 0, 128800, "ALICE"},
    {1, 1,  85600, "BOB"},
    {1, 2,  32000, "CARD2"},
};

static char key_to_char(u8 code)
{
    static const char map[16] = {
        '1', '2', '3', 'A',
        '4', '5', '6', 'B',
        '7', '8', '9', 'C',
        '*', '0', '#', 'D'
    };
    return map[code & 0x0F];
}

static int key_digit(char key)
{
    return (key >= '0' && key <= '9') ? key - '0' : -1;
}

static void beep(u32 mask)
{
    Xil_Out32(REG_BUZZER, mask);
}

static void leds(u32 value)
{
    Xil_Out32(REG_LED, value & 0x0F);
}

static void vga_put_char(u8 row, u8 col, char ch)
{
    u32 addr = (u32)row * VGA_COLS + col;
    Xil_Out32(REG_VGA_CHAR, (1u << 31) | (addr << 12) | (u8)ch);
    usleep(20);
}

static void vga_clear(void)
{
    u32 i;
    for (i = 0; i < VGA_COLS * VGA_ROWS; i++) {
        Xil_Out32(REG_VGA_CHAR, (1u << 31) | (i << 12) | ' ');
    }
}

static void vga_puts(u8 row, u8 col, const char *s)
{
    while (*s && col < VGA_COLS) {
        vga_put_char(row, col++, *s++);
    }
}

static void vga_put_u32(u8 row, u8 col, u32 value)
{
    char buf[11];
    int i = 10;
    buf[i] = 0;
    if (value == 0) {
        vga_put_char(row, col, '0');
        return;
    }
    while (value && i > 0) {
        buf[--i] = '0' + (value % 10);
        value /= 10;
    }
    vga_puts(row, col, &buf[i]);
}

static void vga_put_money(u8 row, u8 col, u32 cents)
{
    u32 yuan = cents / 100;
    u8 digits = 1;
    u32 tmp = yuan;
    while (tmp >= 10) {
        tmp /= 10;
        digits++;
    }
    vga_put_u32(row, col, yuan);
    vga_put_char(row, col + digits, '.');
    vga_put_char(row, col + digits + 1, '0' + ((cents / 10) % 10));
    vga_put_char(row, col + digits + 2, '0' + (cents % 10));
}

static void screen_header(const char *title)
{
    vga_clear();
    vga_puts(0, 0, "FP PAYMENT SYSTEM");
    vga_puts(1, 0, "----------------");
    vga_puts(3, 0, title);
}

static int poll_key(char *out)
{
    u32 data = Xil_In32(REG_KB_DATA);
    if ((data >> 4) & 1u) {
        *out = key_to_char(data & 0x0F);
        beep(BEEP_SHORT);
        usleep(160000);
        return 1;
    }
    return 0;
}

static char wait_key(void)
{
    char key;
    while (!poll_key(&key)) {
        usleep(10000);
    }
    xil_printf("KEY %c\r\n", key);
    return key;
}

static void wait_any_key(void)
{
    vga_puts(24, 0, "# OK");
    while (wait_key() != '#') {
    }
}

static int fp_exec(const char *name, u8 opcode, u16 param, int timeout_ms, u16 *response)
{
    int ticks = timeout_ms / 10;
    Xil_Out32(REG_FP_CMD, (1u << 31) | ((u32)opcode << 16) | param);
    while (ticks-- > 0) {
        u32 resp = Xil_In32(REG_FP_RESP);
        u32 status = (resp >> 24) & 0xFF;
        if (status == 2) {
            if (response) *response = resp & 0xFFFF;
            xil_printf("FP %s OK resp=0x%04lx\r\n", name, resp & 0xFFFF);
            return 0;
        }
        if (status == 3) {
            if (response) *response = resp & 0xFFFF;
            xil_printf("FP %s ERR code=0x%02lx dbg=0x%08lx\r\n",
                       name, resp & 0xFF, Xil_In32(REG_FP_DBG));
            return (int)(resp & 0xFF);
        }
        usleep(10000);
    }
    xil_printf("FP %s TIMEOUT dbg=0x%08lx\r\n", name, Xil_In32(REG_FP_DBG));
    return 0x100;
}

static int fp_self_test(void)
{
    u16 resp = 0;
    screen_header("SELF TEST");
    vga_puts(5, 0, "AS608 LINK...");
    leds(0x1);
    if (fp_exec("VfyPwd", FP_VFY_PWD, 0, 10000, &resp) != 0) {
        vga_puts(6, 0, "FAIL");
        beep(BEEP_FAIL);
        leds(0x8);
        return 0;
    }
    vga_puts(6, 0, "PWD OK");
    fp_exec("ReadSysPara", FP_READ_SYS_PARA, 0, 10000, &resp);
    if (fp_exec("ValidTmplNum", FP_VALID_TMPL_NUM, 0, 10000, &resp) == 0) {
        vga_puts(8, 0, "TEMPLATES:");
        vga_put_u32(8, 11, resp);
    }
    beep(BEEP_OK);
    leds(0x3);
    return 1;
}

static int fp_capture_to_buffer(u8 buffer_id, const char *prompt)
{
    int tries;
    u16 resp;
    vga_puts(6, 0, prompt);
    vga_puts(7, 0, "PLACE FINGER");
    for (tries = 0; tries < 40; tries++) {
        int rc = fp_exec("GetImage", FP_GET_IMAGE, 0, 9000, &resp);
        if (rc == 0) {
            vga_puts(8, 0, "IMAGE OK");
            rc = fp_exec("GenChar", FP_GEN_CHAR, buffer_id, 9000, &resp);
            if (rc == 0) return 0;
            vga_puts(9, 0, "GEN FAIL");
            return rc;
        }
        if (rc != 0x02) {
            vga_puts(8, 0, "SENSOR FAIL");
            return rc;
        }
        usleep(250000);
    }
    vga_puts(8, 0, "NO FINGER");
    return 0x101;
}

static account_t *find_account_by_template(u16 template_id)
{
    int i;
    for (i = 0; i < MAX_ACCOUNTS; i++) {
        if (accounts[i].active && accounts[i].template_id == template_id) {
            return &accounts[i];
        }
    }
    return 0;
}

static account_t *find_account_by_index(u8 index)
{
    if (index < MAX_ACCOUNTS && accounts[index].active) {
        return &accounts[index];
    }
    return 0;
}

static account_t *verify_fingerprint(void)
{
    u16 page_id = 0;
    int rc;
    leds(0x2);
    rc = fp_capture_to_buffer(1, "VERIFY");
    if (rc != 0) return 0;
    vga_puts(10, 0, "SEARCH...");
    rc = fp_exec("Search", FP_SEARCH, (1u << 8) | MAX_ACCOUNTS, 10000, &page_id);
    if (rc != 0) {
        vga_puts(11, 0, "NO MATCH");
        return 0;
    }
    vga_puts(11, 0, "ID:");
    vga_put_u32(11, 3, page_id);
    return find_account_by_template(page_id);
}

static u32 input_amount(void)
{
    u32 yuan = 0;
    while (1) {
        char key;
        screen_header("INPUT AMOUNT");
        vga_puts(5, 0, "YUAN:");
        vga_put_u32(5, 6, yuan);
        vga_puts(7, 0, "# OK   * CLR");
        key = wait_key();
        if (key == '#') return yuan * 100;
        if (key == '*') yuan = 0;
        else {
            int d = key_digit(key);
            if (d >= 0 && yuan < 10000) {
                yuan = yuan * 10 + (u32)d;
            }
        }
    }
}

static void show_account(account_t *acct)
{
    screen_header("ACCOUNT");
    if (!acct) {
        vga_puts(5, 0, "NOT FOUND");
        beep(BEEP_FAIL);
        wait_any_key();
        return;
    }
    vga_puts(5, 0, "NAME:");
    vga_puts(5, 6, acct->name);
    vga_puts(7, 0, "ID:");
    vga_put_u32(7, 4, acct->template_id);
    vga_puts(9, 0, "BAL:");
    vga_put_money(9, 5, acct->balance_cents);
    wait_any_key();
}

static void payment_flow(void)
{
    u32 amount = input_amount();
    account_t *acct;
    if (amount == 0) return;

    screen_header("PAY");
    vga_puts(5, 0, "AMOUNT:");
    vga_put_money(5, 8, amount);
    acct = verify_fingerprint();
    if (!acct) {
        vga_puts(13, 0, "VERIFY FAIL");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_any_key();
        return;
    }

    vga_puts(13, 0, acct->name);
    if (acct->balance_cents < amount) {
        vga_puts(15, 0, "BAL LOW");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_any_key();
        return;
    }

    acct->balance_cents -= amount;
    vga_puts(15, 0, "PAID OK");
    vga_puts(17, 0, "BAL:");
    vga_put_money(17, 5, acct->balance_cents);
    beep(BEEP_OK);
    leds(0x4);
    wait_any_key();
}

static void balance_flow(void)
{
    account_t *acct;
    screen_header("BALANCE");
    acct = verify_fingerprint();
    if (!acct) {
        vga_puts(13, 0, "VERIFY FAIL");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_any_key();
        return;
    }
    show_account(acct);
}

static void enroll_flow(void)
{
    char key;
    int index;
    u16 resp;
    account_t *acct;
    screen_header("ENROLL");
    vga_puts(5, 0, "ACCOUNT 0-9:");
    key = wait_key();
    index = key_digit(key);
    if (index < 0) return;
    acct = &accounts[index];
    acct->active = 1;
    acct->template_id = (u16)index;
    if (acct->balance_cents == 0) {
        acct->balance_cents = 50000;
    }

    screen_header("ENROLL");
    vga_puts(5, 0, "FIRST");
    if (fp_capture_to_buffer(1, "FIRST") != 0) goto fail;
    vga_puts(12, 0, "LIFT FINGER");
    sleep(2);
    vga_puts(14, 0, "SECOND");
    if (fp_capture_to_buffer(2, "SECOND") != 0) goto fail;
    if (fp_exec("RegModel", FP_REG_MODEL, 0, 10000, &resp) != 0) goto fail;
    if (fp_exec("StoreChar", FP_STORE_CHAR, (1u << 8) | (u16)index, 10000, &resp) != 0) goto fail;

    vga_puts(18, 0, "ENROLL OK");
    beep(BEEP_OK);
    leds(0x7);
    wait_any_key();
    return;

fail:
    vga_puts(18, 0, "ENROLL FAIL");
    beep(BEEP_FAIL);
    leds(0x8);
    wait_any_key();
}

static void menu(void)
{
    screen_header("READY");
    vga_puts(5, 0, "A PAY");
    vga_puts(7, 0, "B BALANCE");
    vga_puts(9, 0, "C ENROLL");
    vga_puts(11, 0, "D SELF TEST");
    vga_puts(14, 0, "KEYS: # OK  * CLR");
    leds(0x1);
}

int main(void)
{
    xil_printf("\r\nFP Payment System\r\n");
    vga_clear();
    screen_header("BOOT");
    vga_puts(5, 0, "WAIT AS608");
    sleep(1);
    fp_self_test();
    sleep(1);

    while (1) {
        char key;
        menu();
        key = wait_key();
        switch (key) {
        case 'A': payment_flow(); break;
        case 'B': balance_flow(); break;
        case 'C': enroll_flow(); break;
        case 'D':
            fp_self_test();
            wait_any_key();
            break;
        default:
            beep(BEEP_FAIL);
            break;
        }
    }

    return 0;
}
