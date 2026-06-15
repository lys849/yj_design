# MicroBlaze 平台分步验证

Vivado 2022.2 + MicroBlaze，每步独立可烧录测试。

## Step 1: LED Blink
最小 MicroBlaze 系统 + AXI GPIO(LED)，验证 CPU 能运行。

## Step 2: UART Hello
加 AXI UART Lite（板载 FT2232），验证串口通信。

## Step 3: Custom Peripheral
创建自定义 AXI-Lite IP（包含键盘模块），验证寄存器读写。

## Step 4: All Peripherals
完整 AXI-Lite 外设 IP（包含全部 5 个模块），逐一验证。

> 各步骤的详细 Block Design 搭建指南将在实施时补充。
