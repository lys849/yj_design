// Step 2: UART Hello — 验证串口通信
#include "xil_printf.h"
#include "xparameters.h"
#include "xgpio.h"
#include "sleep.h"

#ifdef XPAR_AXI_GPIO_0_DEVICE_ID
#define LED_GPIO_ID XPAR_AXI_GPIO_0_DEVICE_ID
#else
#define LED_GPIO_ID XPAR_AXI_GPIO_0_BASEADDR
#endif

int main(void)
{
    XGpio gpio;
    XGpio_Initialize(&gpio, LED_GPIO_ID);
    XGpio_SetDataDirection(&gpio, 1, 0x0);

    xil_printf("\r\n==============================\r\n");
    xil_printf(" Hello from MicroBlaze!\r\n");
    xil_printf(" Nexys4 DDR - Step 2 UART Test\r\n");
    xil_printf("==============================\r\n\r\n");

    u32 count = 0;
    while (1) {
        XGpio_DiscreteWrite(&gpio, 1, count & 0xF);
        xil_printf("Count: %lu\r\n", count);
        count++;
        sleep(1);
    }

    return 0;
}
