// Step 1: LED 跑马灯 — 验证 MicroBlaze 能正常运行
#include "xparameters.h"
#include "xgpio.h"
#include "sleep.h"

#define LED_GPIO_ID   XPAR_AXI_GPIO_0_DEVICE_ID
#define LED_CHANNEL   1

int main(void)
{
    XGpio gpio;
    XGpio_Initialize(&gpio, LED_GPIO_ID);
    XGpio_SetDataDirection(&gpio, LED_CHANNEL, 0x0);

    u32 led = 0x1;

    while (1) {
        XGpio_DiscreteWrite(&gpio, LED_CHANNEL, led);
        usleep(200000);
        led = (led >= 0x8) ? 0x1 : (led << 1);
    }

    return 0;
}
