// Step 3: 键盘外设测试 — 验证自定义 AXI-Lite IP 能工作
#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"
#include "xgpio.h"
#include "sleep.h"

#define KB_PERIPH_BASE XPAR_KB_PERIPH_0_BASEADDR
#define KB_DATA_REG    (KB_PERIPH_BASE + 0x00)

#define LED_GPIO_ID    XPAR_AXI_GPIO_0_DEVICE_ID

int main(void)
{
    XGpio gpio;
    XGpio_Initialize(&gpio, LED_GPIO_ID);
    XGpio_SetDataDirection(&gpio, 1, 0x0);

    xil_printf("\r\n================================\r\n");
    xil_printf(" Step 3: Keyboard Peripheral Test\r\n");
    xil_printf("================================\r\n");
    xil_printf("Press keys on 4x4 keypad...\r\n\r\n");

    while (1) {
        u32 kb_data = Xil_In32(KB_DATA_REG);
        u32 valid   = (kb_data >> 4) & 0x1;
        u32 code    = kb_data & 0xF;

        if (valid) {
            xil_printf("Key pressed: code=%d\r\n", code);
            XGpio_DiscreteWrite(&gpio, 1, code);
        }

        usleep(10000);
    }

    return 0;
}
