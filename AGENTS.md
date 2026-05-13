# AGENTS.md

## Project
指纹识别的支付系统 — 硬件技术课程设计。Xilinx FPGA + MicroBlaze 软核，Verilog 实现硬件接口，C 语言实现业务逻辑。

目标开发板：**Digilent Nexys4 DDR**（XC7A100T-1CSG324C），引脚约束见 `demo/nexys4.xdc`。

## Environment
- 使用 conda 的 `llm` 虚拟环境
- Verilog 仿真器：`iverilog` + `vvp`（通过 `brew install icarus-verilog` 安装）
- `.doc` 文件为二进制格式，需用 `textutil -convert txt -stdout <file>.doc` 读取
- `python-docx` 和 `python-pptx` 已在 llm 环境中可用

## Architecture
```
demo/
  rtl/    — Verilog 硬件模块（UART、VGA、键盘、指纹控制器、蜂鸣器、SPI Flash、顶层集成）
  sw/     — MicroBlaze C 代码（主控状态机、账户管理、支付、显示、存储）
  tb/     — Testbench 仿真测试
```

### 模块依赖关系
- `top.v` 是最顶层，依赖所有 rtl 模块，对外提供寄存器映射供 C 代码访问
- `uart_tx.v` + `uart_rx.v` 被 `fingerprint_ctrl.v` 实例化
- `vga_text.v` 内部包含 `font_rom` 模块，渲染 5×7 ASCII 字库

## Key docs
- `2硬件技术课程设计任务书（指纹识别的支付系统）.doc`
- `2硬件技术课程设计指导书（指纹识别的支付系统）.doc`
- `硬件课程设计-Xia2026-20260511210333.pdf`
- `N4.pdf` — Nexys4 参考手册（引脚分配、电路原理）
- `demo/nexys4.xdc` — Vivado 引脚约束文件

## Commands

### Run individual testbench
```bash
# Single module test (example: UART)
cd demo
iverilog -o tb/uart_tb.out tb/uart_tb.v rtl/uart_tx.v rtl/uart_rx.v && vvp tb/uart_tb.out

# VGA
iverilog -o tb/vga_tb.out tb/vga_tb.v rtl/vga_ctrl.v && vvp tb/vga_tb.out

# Keyboard
iverilog -o tb/keyboard_tb.out tb/keyboard_tb.v rtl/keyboard_scan.v && vvp tb/keyboard_tb.out

# Fingerprint
iverilog -o tb/fingerprint_tb.out tb/fingerprint_tb.v rtl/fingerprint_ctrl.v rtl/uart_tx.v rtl/uart_rx.v && vvp tb/fingerprint_tb.out

# Top-level integration (all modules)
iverilog -o tb/top_tb.out tb/top_tb.v rtl/top.v rtl/uart_tx.v rtl/uart_rx.v rtl/vga_ctrl.v rtl/vga_text.v rtl/keyboard_scan.v rtl/buzzer_ctrl.v rtl/spi_flash.v rtl/fingerprint_ctrl.v && vvp tb/top_tb.out
```

### Verify all RTL compiles
```bash
cd demo
iverilog -o /tmp/all_test.out rtl/*.v
```

### Generate documents
```bash
conda run -n llm python3 generate_report.py
```

## Gotchas
- `iverilog` 不支持 Verilog 表达式结果的部分选择（如 `(a + b)[6:0]`），需先计算到中间变量
- `iverilog` 要求 `reg` 和 `wire` 在使用前声明；模块输入端口连接的 reg 必须在实例化前声明
- UART TX 的 bit 索引需从 0 开始（对应 bit 0 = LSB），bit_idx 0→7 输出数据位，8 输出停止位
- `.doc` 二进制文件不可直接 `cat`/`grep`，用 `textutil` 转换

## Nexys4 Board Notes
- VGA 为 12 位色深（R/G/B 各 4 位），非 24 位；`vga_r/g/b` 已降为 `[3:0]`
- `clk_gen` 模块为纯仿真分频器，Vivado 综合时需替换为 MMCM/PLL（使用 Clocking Wizard IP）
- CPU_RESET（C12）为低有效；BTNC（D9）为高有效——当前 `rst_n` 接 C12
- `spi_flash.v` 中的 `spi_clk_d` 边沿检测存在时序问题，综合前建议将 clk_d 采样放在状态机之前
- PMOD 引脚：键盘用 JB（4行+4列），指纹传感器 UART 用 JD（TX+TX）
