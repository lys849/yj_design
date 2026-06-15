// Step 4: 全外设测试 — 逐一验证键盘、指纹、蜂鸣器、LED
#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"
#include "sleep.h"

#define PERIPH_BASE  XPAR_FP_PAYMENT_PERIPH_0_BASEADDR

#define REG_FP_CMD   (PERIPH_BASE + 0x00)
#define REG_FP_RESP  (PERIPH_BASE + 0x04)
#define REG_KB_DATA  (PERIPH_BASE + 0x08)
#define REG_BUZZER   (PERIPH_BASE + 0x0C)
#define REG_VGA_CHAR (PERIPH_BASE + 0x10)
#define REG_LED      (PERIPH_BASE + 0x14)

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
    xil_printf("[FINGERPRINT] Sending VfyPwd (default password 0x00000000)...\r\n");
    Xil_Out32(REG_FP_CMD, (1u << 31) | (0x13 << 16) | 0x0000);

    int timeout = 500;
    while (timeout-- > 0) {
        u32 resp = Xil_In32(REG_FP_RESP);
        u32 status = (resp >> 24) & 0xFF;
        if (status == 2) {
            xil_printf("  Sensor responded: OK (password verified)\r\n");
            break;
        } else if (status == 3) {
            xil_printf("  Sensor responded: ERROR (code=0x%02lx)\r\n", resp & 0xFF);
            break;
        }
        usleep(10000);
    }
    if (timeout <= 0) {
        xil_printf("  Sensor timeout - check wiring on PMOD JD\r\n");
    }
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
