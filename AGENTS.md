# AGENTS.md

## Project
指纹识别的支付系统 — 硬件技术课程设计。Xilinx FPGA + MicroBlaze 软核，Verilog 实现硬件接口，C 语言实现业务逻辑。

目标开发板：**Digilent Nexys4 DDR**（XC7A100T-1CSG324C），Vivado **2022.2**。

## Environment
- 使用 conda 的 `llm` 虚拟环境
- Verilog 仿真器：`iverilog` + `vvp`（通过 `brew install icarus-verilog` 安装）
- `.doc` 文件为二进制格式，需用 `textutil -convert txt -stdout <file>.doc` 读取
- `python-docx` 和 `python-pptx` 已在 llm 环境中可用

## Architecture
```
project/                              # 主开发目录（MicroBlaze 路线）
  modules/                            # 5 个独立外设模块，各含 rtl/ + sim/ + board_test/
    uart/                             # UART TX/RX（STOP_BITS 可配置，默认 1，指纹用 2）
    keyboard/                         # 4×4 矩阵键盘（µs 级行驻留 + 输入同步 + 消抖）
    vga/                              # VGA 时序控制 + 文字渲染（BRAM 字符缓冲 + font_rom）
    fingerprint/                      # AS608 指纹控制器（完整协议包构建 + 应答解析）
    buzzer/                           # PWM 蜂鸣器（边沿触发，3 种音效）
  platform_test/                      # MicroBlaze 分步验证（step1-4）
    step1_led_blink/                  # 最小系统: MicroBlaze + AXI GPIO → LED 跑马灯
    step2_uart_hello/                 # + AXI UART Lite → 串口 Hello World
    step3_custom_periph/              # + 自定义 AXI-Lite IP（键盘）→ 串口打印键码
    step4_all_periph/                 # + 完整 AXI-Lite IP（5 模块）→ 逐一验证
    每步含: README_manual.md + README_tcl.md + vivado/*.tcl + sw/main.c
  system/                             # 完整系统（AXI-Lite IP + C 代码）
  shared/nexys4_base.xdc              # 公共引脚约束

demo/                                 # 旧原型代码（参考用，有已知硬件 bug，不可直接烧板）
```

### 设计决策
- **去掉 SPI Flash 模块**：板载 Flash 与 FPGA 配置共享（需 STARTUPE2 原语），改用 MicroBlaze BRAM 存账户数据（32×64B=2KB），演示时保持上电即可
- **单个 AXI-Lite 外设 IP** 包装全部 5 个模块，避免多 IP 复杂互连
- 每个模块含 `board_test/` 可独立烧板验证（顶层 wrapper + 独立 XDC）

### 模块依赖关系
- `fingerprint_ctrl.v` 内部例化 `uart_tx`/`uart_rx`（STOP_BITS=2）
- `vga_text.v` 内含 `font_rom` 子模块，字符缓冲 2400B 用 `initial` 初始化以推断 BRAM
- 板级测试中 VGA 需 25MHz 时钟，`vga_test_top.v` 使用 `MMCME2_BASE` 原语生成

## Key docs
- `2硬件技术课程设计任务书（指纹识别的支付系统）.doc`
- `2硬件技术课程设计指导书（指纹识别的支付系统）.doc`
- `硬件课程设计-Xia2026-20260511210333.pdf`
- `N4.pdf` / `Nexys4ddr_rm.pdf` — Nexys4 DDR 参考手册
- `厂家资料/AS60x指纹识别SOC通讯手册V10.pdf` — AS608 UART 协议详解（包格式、指令集、确认码）
- `project/shared/nexys4_base.xdc` — 主引脚约束文件
- `PINOUT.md` / `PARTS_LIST.md` — 引脚和器件速查，部分引脚值已过时，**以 XDC 文件为准**

## Commands

### project/ 模块仿真（推荐）
```bash
cd project

# UART 回环
iverilog -o /tmp/uart_tb.out modules/uart/sim/uart_tb.v modules/uart/rtl/uart_tx.v modules/uart/rtl/uart_rx.v && vvp /tmp/uart_tb.out

# 键盘
iverilog -o /tmp/kb_tb.out modules/keyboard/sim/keyboard_tb.v modules/keyboard/rtl/keyboard_scan.v && vvp /tmp/kb_tb.out

# VGA（编译验证，全帧仿真耗时长）
iverilog -o /tmp/vga_tb.out modules/vga/sim/vga_tb.v modules/vga/rtl/vga_ctrl.v modules/vga/rtl/vga_text.v

# 蜂鸣器
iverilog -o /tmp/buzzer_tb.out modules/buzzer/sim/buzzer_tb.v modules/buzzer/rtl/buzzer_ctrl.v && vvp /tmp/buzzer_tb.out

# 指纹（依赖 uart 模块）
iverilog -o /tmp/fp_tb.out modules/fingerprint/sim/fingerprint_tb.v modules/fingerprint/rtl/fingerprint_ctrl.v modules/uart/rtl/uart_tx.v modules/uart/rtl/uart_rx.v && vvp /tmp/fp_tb.out

# 所有 RTL 编译检查
iverilog -o /tmp/all_modules.out modules/uart/rtl/*.v modules/keyboard/rtl/*.v modules/vga/rtl/*.v modules/buzzer/rtl/*.v modules/fingerprint/rtl/*.v
```

### demo/ 旧代码仿真（仅参考）
```bash
cd demo
iverilog -o /tmp/all_test.out rtl/*.v
```

### 生成文档
```bash
conda run -n llm python3 generate_report.py
```

## Gotchas
- `iverilog` 不支持 Verilog 表达式结果的部分选择（如 `(a + b)[6:0]`），需先计算到中间变量
- `iverilog` 要求 `reg` 和 `wire` 在使用前声明；模块输入端口连接的 reg 必须在实例化前声明
- `iverilog` 不支持 unnamed block 内的 `integer` 声明（Verilog-2001 限制），需将 `integer` 声明放在模块级别
- AS608 指纹模块 UART 要求 **2 位停止位（8N2）**，`uart_tx`/`uart_rx` 通过 `STOP_BITS` 参数控制（默认 1），`fingerprint_ctrl` 内部已设为 2
- AS608 数据包格式：`Header(EF01) + Addr(4B) + PkgID(01) + Len(2B) + Instr + Params + Chksum(2B)`，校验和从包标识累加到参数末尾
- `.doc` 二进制文件不可直接 `cat`/`grep`，用 `textutil` 转换
- BRAM 初始化必须用 `initial` 块（非 `always` 块的 for 循环），否则 Vivado 无法推断 BRAM 会消耗大量 LUT
- VGA 字符缓冲用真双端口 BRAM 模式解决跨时钟域（写端口 CPU 时钟，读端口像素时钟）
- 板载 QSPI Flash 时钟需通过 `STARTUPE2` 原语访问，不可直接分配引脚——项目已改用 BRAM 存储

## Nexys4 Board Notes
- VGA 为 12 位色深（R/G/B 各 4 位），非 24 位；`vga_r/g/b` 为 `[3:0]`
- 时钟生成必须用 `MMCME2_BASE` 或 Clocking Wizard IP，不可用触发器分频（无 BUFG = 时钟偏斜）
- CPU_RESET（C12）为低有效；BTNC/BTNU/BTND 为高有效
- PMOD 引脚：键盘用 JB（4行+4列），指纹传感器 UART 用 JD（TX+RX），蜂鸣器用 JC（JC4=G6）
