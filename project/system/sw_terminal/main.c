// Terminal UI version of the complete fingerprint payment system.
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
#define REG_LED      (PERIPH_BASE + 0x14)
#define REG_FP_DBG   (PERIPH_BASE + 0x18)
#define REG_BTN_DATA (PERIPH_BASE + 0x1C)

#define MAX_ACCOUNTS 32

#define BEEP_SHORT 0x01
#define BEEP_OK    0x02
#define BEEP_FAIL  0x04

#define BTN_CONFIRM 0x01
#define BTN_CLEAR   0x02

#define FP_GET_IMAGE      0x01
#define FP_GEN_CHAR       0x02
#define FP_SEARCH         0x04
#define FP_REG_MODEL      0x05
#define FP_STORE_CHAR     0x06
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

static void term_line(void)
{
    xil_printf("\r\n----------------------------------------\r\n");
}

static void term_header(const char *title)
{
    term_line();
    xil_printf("FP PAYMENT SYSTEM - %s\r\n", title);
    term_line();
}

static void term_money(u32 cents)
{
    xil_printf("%lu.", cents / 100);
    xil_printf("%c", '0' + ((cents / 10) % 10));
    xil_printf("%c", '0' + (cents % 10));
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

static u32 poll_buttons(void)
{
    u32 data = Xil_In32(REG_BTN_DATA) & 0x03;
    if (data) {
        beep(BEEP_SHORT);
        usleep(160000);
    }
    return data;
}

static char wait_menu_key(void)
{
    char key;
    while (1) {
        if (poll_key(&key)) {
            if (key >= 'A' && key <= 'D') {
                xil_printf("KEY %c\r\n", key);
                return key;
            }
            xil_printf("Ignored key %c. Use A/B/C/D for menu.\r\n", key);
        }
        usleep(10000);
    }
}

static u32 wait_button(void)
{
    u32 btn;
    while (1) {
        btn = poll_buttons();
        if (btn) {
            xil_printf("BTN %s\r\n", (btn & BTN_CONFIRM) ? "CONFIRM" : "CLEAR");
            return btn;
        }
        usleep(10000);
    }
}

static void wait_confirm(void)
{
    xil_printf("\r\nPress BTNC to continue.\r\n");
    while ((wait_button() & BTN_CONFIRM) == 0) {
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
    term_header("SELF TEST");
    xil_printf("Checking AS608 link...\r\n");
    leds(0x1);
    if (fp_exec("VfyPwd", FP_VFY_PWD, 0, 10000, &resp) != 0) {
        xil_printf("AS608 password verify failed.\r\n");
        beep(BEEP_FAIL);
        leds(0x8);
        return 0;
    }
    fp_exec("ReadSysPara", FP_READ_SYS_PARA, 0, 10000, &resp);
    if (fp_exec("ValidTmpl", FP_VALID_TMPL_NUM, 0, 10000, &resp) == 0) {
        xil_printf("Template count: %lu\r\n", (u32)resp);
    }
    beep(BEEP_OK);
    leds(0x3);
    return 1;
}

static int fp_capture_to_buffer(u8 buffer_id, const char *prompt)
{
    int tries;
    u16 resp;
    xil_printf("\r\n%s: place finger on AS608.\r\n", prompt);
    for (tries = 0; tries < 40; tries++) {
        int rc = fp_exec("GetImage", FP_GET_IMAGE, 0, 9000, &resp);
        if (rc == 0) {
            xil_printf("Image captured. Generating character buffer %lu...\r\n", (u32)buffer_id);
            rc = fp_exec("GenChar", FP_GEN_CHAR, buffer_id, 9000, &resp);
            if (rc == 0) return 0;
            xil_printf("GenChar failed.\r\n");
            return rc;
        }
        if (rc != 0x02) {
            xil_printf("Sensor returned unexpected capture error 0x%02x.\r\n", rc);
            return rc;
        }
        usleep(250000);
    }
    xil_printf("No finger detected before timeout.\r\n");
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

static account_t *verify_fingerprint(void)
{
    u16 page_id = 0;
    int rc;
    leds(0x2);
    rc = fp_capture_to_buffer(1, "VERIFY");
    if (rc != 0) return 0;

    xil_printf("Searching AS608 template library...\r\n");
    rc = fp_exec("Search", FP_SEARCH, (1u << 8) | MAX_ACCOUNTS, 10000, &page_id);
    if (rc != 0) {
        xil_printf("No matching fingerprint.\r\n");
        return 0;
    }
    xil_printf("Matched template ID: %lu\r\n", (u32)page_id);
    return find_account_by_template(page_id);
}

static u32 input_amount(void)
{
    u32 yuan = 0;
    char key;
    u32 btn;

    term_header("INPUT AMOUNT");
    xil_printf("Use keypad digits. BTNC=confirm, BTND=clear/cancel.\r\n");
    xil_printf("Amount: 0\r\n");

    while (1) {
        if (poll_key(&key)) {
            int d = key_digit(key);
            if (d >= 0 && yuan < 10000) {
                yuan = yuan * 10 + (u32)d;
                xil_printf("Amount: %lu\r\n", yuan);
            } else {
                xil_printf("Ignored key %c. Use digits only here.\r\n", key);
            }
        }

        btn = poll_buttons();
        if (btn & BTN_CLEAR) {
            yuan = 0;
            xil_printf("Amount cleared.\r\nAmount: 0\r\n");
        }
        if (btn & BTN_CONFIRM) {
            xil_printf("Confirmed amount: %lu yuan\r\n", yuan);
            return yuan * 100;
        }
        usleep(10000);
    }
}

static void show_account(account_t *acct)
{
    if (!acct) {
        xil_printf("Account not found.\r\n");
        beep(BEEP_FAIL);
        wait_confirm();
        return;
    }
    xil_printf("Account: %s\r\n", acct->name);
    xil_printf("Template ID: %lu\r\n", (u32)acct->template_id);
    xil_printf("Balance: ");
    term_money(acct->balance_cents);
    xil_printf(" yuan\r\n");
    wait_confirm();
}

static void payment_flow(void)
{
    u32 amount = input_amount();
    account_t *acct;
    if (amount == 0) {
        xil_printf("Zero amount, payment cancelled.\r\n");
        wait_confirm();
        return;
    }

    term_header("PAY");
    xil_printf("Payment amount: ");
    term_money(amount);
    xil_printf(" yuan\r\n");

    acct = verify_fingerprint();
    if (!acct) {
        xil_printf("Fingerprint verify failed.\r\n");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_confirm();
        return;
    }

    xil_printf("Verified account: %s\r\n", acct->name);
    if (acct->balance_cents < amount) {
        xil_printf("Insufficient balance. Current: ");
        term_money(acct->balance_cents);
        xil_printf(" yuan\r\n");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_confirm();
        return;
    }

    acct->balance_cents -= amount;
    xil_printf("Payment OK. New balance: ");
    term_money(acct->balance_cents);
    xil_printf(" yuan\r\n");
    beep(BEEP_OK);
    leds(0x4);
    wait_confirm();
}

static void balance_flow(void)
{
    account_t *acct;
    term_header("BALANCE");
    acct = verify_fingerprint();
    if (!acct) {
        xil_printf("Fingerprint verify failed.\r\n");
        beep(BEEP_FAIL);
        leds(0x8);
        wait_confirm();
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

    term_header("ENROLL");
    xil_printf("Press account digit 0-9 on keypad. BTND cancels.\r\n");
    while (1) {
        u32 btn = poll_buttons();
        if (btn & BTN_CLEAR) {
            xil_printf("Enroll cancelled.\r\n");
            return;
        }
        if (poll_key(&key)) {
            index = key_digit(key);
            if (index >= 0) break;
            xil_printf("Ignored key %c. Use digit 0-9.\r\n", key);
        }
        usleep(10000);
    }

    acct = &accounts[index];
    acct->active = 1;
    acct->template_id = (u16)index;
    if (acct->balance_cents == 0) {
        acct->balance_cents = 50000;
    }

    xil_printf("Enroll account %d, template page %d.\r\n", index, index);
    xil_printf("Press BTNC when ready for first capture, BTND to cancel.\r\n");
    if (wait_button() & BTN_CLEAR) return;
    if (fp_capture_to_buffer(1, "FIRST CAPTURE") != 0) goto fail;

    xil_printf("Lift finger, then press BTNC for second capture.\r\n");
    sleep(2);
    if (wait_button() & BTN_CLEAR) return;
    if (fp_capture_to_buffer(2, "SECOND CAPTURE") != 0) goto fail;

    if (fp_exec("RegModel", FP_REG_MODEL, 0, 10000, &resp) != 0) goto fail;
    if (fp_exec("StoreChar", FP_STORE_CHAR, (1u << 8) | (u16)index, 10000, &resp) != 0) goto fail;

    xil_printf("Enroll OK for account %d.\r\n", index);
    beep(BEEP_OK);
    leds(0x7);
    wait_confirm();
    return;

fail:
    xil_printf("Enroll failed.\r\n");
    beep(BEEP_FAIL);
    leds(0x8);
    wait_confirm();
}

static void menu(void)
{
    term_header("READY");
    xil_printf("A - Pay\r\n");
    xil_printf("B - Balance\r\n");
    xil_printf("C - Enroll\r\n");
    xil_printf("D - Self test\r\n");
    xil_printf("\r\nInput: keypad A/B/C/D. Buttons: BTNC=confirm, BTND=clear/cancel.\r\n");
    leds(0x1);
}

int main(void)
{
    xil_printf("\r\n\r\nFP Payment System - Terminal UI\r\n");
    xil_printf("Serial: 115200 8N1. Keypad: A/B/C/D and digits. BTNC=confirm, BTND=clear.\r\n");
    sleep(1);
    fp_self_test();
    wait_confirm();

    while (1) {
        char key;
        menu();
        key = wait_menu_key();
        switch (key) {
        case 'A': payment_flow(); break;
        case 'B': balance_flow(); break;
        case 'C': enroll_flow(); break;
        case 'D':
            fp_self_test();
            wait_confirm();
            break;
        default:
            beep(BEEP_FAIL);
            break;
        }
    }

    return 0;
}
