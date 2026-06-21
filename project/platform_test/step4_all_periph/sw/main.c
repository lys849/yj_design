// Step 4: 全外设测试 — 逐一验证键盘、指纹、蜂鸣器、LED
#include "xil_printf.h"
#include "xil_io.h"
#include "xil_types.h"
#include "xparameters.h"
#include "sleep.h"

#define PERIPH_BASE  XPAR_FP_PAYMENT_PERIPH_0_BASEADDR

#define REG_FP_CMD   (PERIPH_BASE + 0x00)
#define REG_FP_RESP  (PERIPH_BASE + 0x04)
#define REG_KB_DATA  (PERIPH_BASE + 0x08)
#define REG_BUZZER   (PERIPH_BASE + 0x0C)
#define REG_VGA_CHAR (PERIPH_BASE + 0x10)
#define REG_LED      (PERIPH_BASE + 0x14)

static const char *fp_status_name(u32 status)
{
    switch (status) {
    case 0: return "idle";
    case 1: return "busy";
    case 2: return "done";
    case 3: return "error";
    default: return "unknown";
    }
}

static int fp_run_command(const char *name, u8 opcode, u16 param, int timeout_ms)
{
    xil_printf("[FINGERPRINT] %s opcode=0x%02x param=0x%04x\r\n",
               name, opcode, param);
    Xil_Out32(REG_FP_CMD, (1u << 31) | ((u32)opcode << 16) | param);

    u32 readback = Xil_In32(REG_FP_CMD);
    xil_printf("  CMD readback=0x%08lx\r\n", readback);

    usleep(1000);
    u32 first_resp = Xil_In32(REG_FP_RESP);
    xil_printf("  RESP after 1ms=0x%08lx (status=%lu/%s response=0x%04lx)\r\n",
               first_resp, (first_resp >> 24) & 0xFF,
               fp_status_name((first_resp >> 24) & 0xFF),
               first_resp & 0xFFFF);

    int timeout = timeout_ms / 10;
    int print_cnt = 0;
    u32 final_resp = first_resp;
    while (timeout-- > 0) {
        u32 resp = Xil_In32(REG_FP_RESP);
        u32 status = (resp >> 24) & 0xFF;
        final_resp = resp;

        if (print_cnt < 5 || (timeout % 200 == 0)) {
            xil_printf("  poll resp=0x%08lx st=%lu/%s response=0x%04lx t=%d\r\n",
                       resp, status, fp_status_name(status),
                       resp & 0xFFFF, timeout);
            print_cnt++;
        }

        if (status == 2) {
            xil_printf("  %s OK: final=0x%08lx response=0x%04lx\r\n",
                       name, resp, resp & 0xFFFF);
            return 1;
        }
        if (status == 3) {
            xil_printf("  %s ERROR: final=0x%08lx code=0x%02lx\r\n",
                       name, resp, resp & 0xFF);
            return 0;
        }

        usleep(10000);
    }

    u32 final_status = (final_resp >> 24) & 0xFF;
    xil_printf("  %s TIMEOUT: final=0x%08lx status=%lu/%s response=0x%04lx\r\n",
               name, final_resp, final_status, fp_status_name(final_status),
               final_resp & 0xFFFF);
    return 0;
}

void test_led(void)
{
    xil_printf("[LED] Running LED test...\r\n");
    int i;
    for (i = 0; i < 4; i++) {
        Xil_Out32(REG_LED, 1 << i);
        xil_printf("  LED[%d] ON\r\n", i);
        usleep(300000);
    }
    Xil_Out32(REG_LED, 0);
    xil_printf("[LED] DONE\r\n\r\n");
}

void test_buzzer(void)
{
    xil_printf("[BUZZER] Short beep...\r\n");
    Xil_Out32(REG_BUZZER, 0x01);
    sleep(1);

    xil_printf("[BUZZER] OK tone...\r\n");
    Xil_Out32(REG_BUZZER, 0x02);
    sleep(1);

    xil_printf("[BUZZER] Fail tone...\r\n");
    Xil_Out32(REG_BUZZER, 0x04);
    sleep(1);

    xil_printf("[BUZZER] DONE\r\n\r\n");
}

void test_keyboard(void)
{
    xil_printf("[KEYBOARD] Press 3 keys on keypad (timeout 10s each)...\r\n");
    int count = 0;
    while (count < 3) {
        u32 data = Xil_In32(REG_KB_DATA);
        if ((data >> 4) & 1) {
            xil_printf("  Key pressed: code=%lu\r\n", data & 0xF);
            count++;
            usleep(300000);
        }
        usleep(10000);
    }
    xil_printf("[KEYBOARD] DONE\r\n\r\n");
}

void test_fingerprint(void)
{
    xil_printf("[FINGERPRINT] Waiting 3s for AS608 boot...\r\n");
    sleep(3);

    int attempt;
    for (attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
            xil_printf("  Retry %d/3...\r\n", attempt + 1);
            usleep(500000);
        }

        if (fp_run_command("VfyPwd default password", 0x13, 0x0000, 10000)) {
            xil_printf("  Sensor responded: OK (password verified)\r\n");
            usleep(100000);
            fp_run_command("ReadSysPara", 0x0F, 0x0000, 10000);
            usleep(100000);
            fp_run_command("ValidTmplNum", 0x1D, 0x0000, 10000);
            xil_printf("[FINGERPRINT] DONE (link success)\r\n\r\n");
            return;
        }
    }
    xil_printf("  All 3 attempts failed - check wiring on PMOD JD\r\n");
    xil_printf("[FINGERPRINT] DONE\r\n\r\n");
}

int main(void)
{
    xil_printf("\r\n========================================\r\n");
    xil_printf(" Step 4: All Peripherals Test\r\n");
    xil_printf(" Nexys4 DDR + MicroBlaze\r\n");
    xil_printf("========================================\r\n\r\n");

    test_led();
    test_buzzer();
    test_keyboard();
    test_fingerprint();

    xil_printf("========================================\r\n");
    xil_printf(" All tests complete!\r\n");
    xil_printf("========================================\r\n");

    while (1) {
        usleep(1000000);
    }

    return 0;
}
