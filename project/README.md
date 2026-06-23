# 指纹识别的支付系统

硬件技术课程设计 — 基于 FPGA 的指纹识别支付系统。

## 一、项目简介

本项目在 Xilinx FPGA 上搭建 MicroBlaze 软核处理器系统，通过 Verilog 实现 5 个硬件外设控制器，使用 C 语言实现上层业务逻辑（账户管理 + 指纹支付）。

**系统功能**：
- 4×4 矩阵键盘进行菜单操作和金额输入
- AS608 光学指纹传感器完成身份认证
- VGA 显示器呈现交互界面（80×30 字符文本）
- 蜂鸣器提供操作音效反馈（按键音 / 成功音 / 失败音）
- 账户数据存储在 MicroBlaze 的 BRAM 中（上电期间有效）

**技术路线**：
```
Verilog 外设控制器 → AXI-Lite 总线 → MicroBlaze 软核 → C 应用程序
     (硬件层)            (总线层)         (处理器)        (软件层)
```

## 二、开发环境

| 项目 | 说明 |
|------|------|
| 开发板 | Digilent Nexys4 DDR（XC7A100T-1CSG324C） |
| FPGA 工具 | Vivado 2022.2 + Vitis 2022.2（Windows） |
| 仿真工具 | Icarus Verilog (`iverilog` + `vvp`)（macOS） |
| 工作流程 | macOS 编写代码 → 同步文件到 Windows → Vivado 综合烧录 |

> Vivado TCL Console 中路径使用**正斜杠**，例如 `cd D:/yj_design/project/platform_test/step1_led_blink`。

## 三、项目结构

```
project/
├── modules/                       # Phase 1: 独立外设模块
│   ├── uart/                      # UART 串口收发
│   ├── keyboard/                  # 4×4 矩阵键盘扫描
│   ├── vga/                       # VGA 时序 + 文字渲染
│   ├── fingerprint/               # AS608 指纹传感器控制
│   └── buzzer/                    # PWM 蜂鸣器
│
├── platform_test/                 # Phase 2: MicroBlaze 平台搭建
│   ├── step1_led_blink/           # 最小系统 → LED 跑马灯
│   ├── step2_uart_hello/          # + 串口 → Hello World
│   ├── step3_custom_periph/       # + 自定义 AXI IP → 键盘测试
│   └── step4_all_periph/          # + 全外设 IP → 逐一验证
│
├── system/                        # Phase 3: 完整系统集成（待实施）
│
├── shared/
│   └── nexys4_base.xdc            # Nexys4 DDR 公共引脚约束
│
└── README.md                      # 本文件
```

### 3.1 modules/ — 外设模块详解

每个模块包含三个子目录：

| 子目录 | 内容 | 用途 |
|--------|------|------|
| `rtl/` | Verilog 源码 | 可综合的硬件描述 |
| `sim/` | 仿真测试文件 | 用 iverilog 在 macOS 上验证逻辑 |
| `board_test/` | 顶层模块 + XDC | 在 Vivado 中独立烧板验证 |

#### 各模块文件说明

**uart/**（UART 串口收发）

| 文件 | 作用 |
|------|------|
| `rtl/uart_tx.v` | 发送器，可配置波特率和停止位（STOP_BITS 参数，默认 1） |
| `rtl/uart_rx.v` | 接收器，2 级同步器防亚稳态，中位采样 |
| `sim/uart_tb.v` | TX→RX 回环测试，5 组数据自动 PASS/FAIL 判定 |
| `board_test/uart_test_top.v` | 板级回环：PC 发字节 → FPGA 原样返回 |
| `board_test/uart_test.xdc` | 时钟 + 复位 + 板载 FT2232 串口引脚 |

**keyboard/**（4×4 矩阵键盘）

| 文件 | 作用 |
|------|------|
| `rtl/keyboard_scan.v` | 行扫描（µs 级驻留）+ 列输入同步 + 20ms 消抖，输出 key_code[3:0] + key_valid 脉冲 |
| `sim/keyboard_tb.v` | 模拟 3 个按键，验证 key_code 正确性 |
| `board_test/kb_test_top.v` | 按键 → LED[3:0] 显示键码 |
| `board_test/kb_test.xdc` | 时钟 + 复位 + PMOD JB（键盘）+ LED |

**vga/**（VGA 显示）

| 文件 | 作用 |
|------|------|
| `rtl/vga_ctrl.v` | 640×480 @ 60Hz 时序控制器（需 25MHz 像素时钟） |
| `rtl/vga_text.v` | 80×30 字符渲染器 + 内嵌 font_rom（8×16 点阵）。字符缓冲用 `initial` 初始化以推断 BRAM |
| `sim/vga_tb.v` | 写入 "HELLO" 并等待两帧渲染完成 |
| `board_test/vga_test_top.v` | 使用 MMCME2_BASE 生成 25MHz，显示 "HELLO VGA TEST" |
| `board_test/vga_test.xdc` | 时钟 + 复位 + VGA 12-bit 引脚 |

**fingerprint/**（AS608 指纹传感器）

| 文件 | 作用 |
|------|------|
| `rtl/fingerprint_ctrl.v` | AS608 协议控制器：首次命令前自动执行 3s boot guard + `0x55` wake + 1s guard，按指令动态构建命令包（12-17 字节），解析可变长度应答。内部例化 uart_tx/rx（默认 57600 8N1；厂家资料标称 8N2，可切 `STOP_BITS=2` 对照） |
| `sim/fingerprint_tb.v` | 发送 VfyPwd / GetImage 命令，验证状态机与无传感器 timeout 路径 |
| `board_test/fp_test_top.v` | 上电后发送 VfyPwd 命令，LED 显示传感器是否应答 |
| `board_test/fp_test.xdc` | 时钟 + 复位 + PMOD JD（AS608 UART）+ LED |

**buzzer/**（PWM 蜂鸣器）

| 文件 | 作用 |
|------|------|
| `rtl/buzzer_ctrl.v` | 1kHz PWM 音频，3 种模式（短蜂鸣 50ms / 成功音 200ms / 失败双响）。触发输入为**边沿检测** |
| `sim/buzzer_tb.v` | 依次触发 3 种模式 |
| `board_test/buzzer_test_top.v` | BTNC / BTNU / BTND 三个按钮触发三种音效 |
| `board_test/buzzer_test.xdc` | 时钟 + 复位 + 按钮 + PMOD JC（蜂鸣器） |

### 3.2 platform_test/ — MicroBlaze 平台验证

每个 step 包含：

| 文件 | 作用 |
|------|------|
| `README_manual.md` | 完整手动操作指南（每步对应 Vivado 菜单操作） |
| `README_tcl.md` | TCL 脚本快捷指南（`source` 命令 + 少量手动操作） |
| `vivado/create_project.tcl` | 一键创建 Vivado 工程（含 XDC 约束） |
| `vivado/create_bd.tcl` | 一键搭建 Block Design（MicroBlaze + 外设） |
| `sw/main.c` | C 测试程序 |
| `ip/*.v`（step3/4） | 自定义 AXI-Lite 外设 Verilog 源码 |

各步骤验证目标：

| Step | 新增内容 | 验证标准 |
|------|---------|---------|
| 1 | MicroBlaze + AXI GPIO | LED 跑马灯闪烁 |
| 2 | + AXI UART Lite | 串口终端看到 "Hello from MicroBlaze" |
| 3 | + 自定义 AXI IP（键盘） | 按键 → 串口打印键码 |
| 4 | + 完整 AXI IP（5 个外设） | 逐一测试 LED / 蜂鸣器 / 键盘 / 指纹 |

### 3.3 system/ — 完整系统集成（Phase 3，待实施）

将包含：
- 完整 AXI-Lite 外设 IP（包装全部模块）
- C 应用代码（主菜单 / 账户管理 / 支付流程 / VGA 显示）
- 最终引脚约束

### 3.4 shared/

| 文件 | 作用 |
|------|------|
| `nexys4_base.xdc` | Nexys4 DDR 全部引脚定义（各 board_test XDC 由此裁剪） |

## 四、实现步骤

### Phase 1：模块仿真验证（macOS，iverilog）

在 macOS 终端中执行。目的是验证每个模块的逻辑正确性。

```bash
cd project

# 1. UART 回环测试
iverilog -o /tmp/uart_tb.out modules/uart/sim/uart_tb.v \
    modules/uart/rtl/uart_tx.v modules/uart/rtl/uart_rx.v \
    && vvp /tmp/uart_tb.out
# 预期: 5 组数据全部 PASS

# 2. 键盘扫描测试
iverilog -o /tmp/kb_tb.out modules/keyboard/sim/keyboard_tb.v \
    modules/keyboard/rtl/keyboard_scan.v \
    && vvp /tmp/kb_tb.out
# 预期: 3/3 passed

# 3. VGA 编译检查（全帧仿真耗时长，仅验证编译）
iverilog -o /tmp/vga_tb.out modules/vga/sim/vga_tb.v \
    modules/vga/rtl/vga_ctrl.v modules/vga/rtl/vga_text.v
# 预期: 无编译错误

# 4. 蜂鸣器测试
iverilog -o /tmp/buzzer_tb.out modules/buzzer/sim/buzzer_tb.v \
    modules/buzzer/rtl/buzzer_ctrl.v \
    && vvp /tmp/buzzer_tb.out
# 预期: BUZZER TEST PASSED

# 5. 指纹控制器测试
iverilog -o /tmp/fp_tb.out modules/fingerprint/sim/fingerprint_tb.v \
    modules/fingerprint/rtl/fingerprint_ctrl.v \
    modules/uart/rtl/uart_tx.v modules/uart/rtl/uart_rx.v \
    && vvp /tmp/fp_tb.out
# 预期: FINGERPRINT TEST PASSED

# 6. 全量编译检查（所有模块无冲突）
iverilog -o /tmp/all_modules.out \
    modules/uart/rtl/*.v modules/keyboard/rtl/*.v \
    modules/vga/rtl/*.v modules/buzzer/rtl/*.v \
    modules/fingerprint/rtl/*.v
# 预期: 无输出（编译成功）
```

**全部通过后，将文件同步到 Windows，进入 Phase 2。**

### Phase 2：模块板级验证（Windows，Vivado）

将每个模块的 `board_test/` 独立烧录到 Nexys4 DDR 上验证真实硬件行为。

每个模块的操作流程相同：
1. 打开 Vivado 2022.2
2. 创建 RTL 工程，选择器件 `xc7a100tcsg324-1`
3. 添加源文件：`board_test/*_test_top.v` + `rtl/*.v`（指纹模块还需添加 `uart/rtl/` 下的文件）
4. 添加约束文件：`board_test/*.xdc`
5. 设置顶层模块（右键 → Set as Top）
6. Generate Bitstream → 等待综合完成
7. Open Hardware Manager → Program Device → 验证结果

各模块验证标准：

| 模块 | 验证方法 | 通过标准 |
|------|---------|---------|
| UART | PC 串口终端发送字符 | 发什么收到什么（回环） |
| 键盘 | 按 4×4 矩阵键盘 | LED 显示对应键码（0-15） |
| VGA | 连接 VGA 显示器 | 屏幕左上角显示 "HELLO VGA TEST" |
| 蜂鸣器 | 按 BTNC / BTNU / BTND | 听到短响 / 长响 / 双响 |
| 指纹 | 连接 AS608 传感器到 JD | LED[0] 亮 = 传感器有应答 |

> **注意**：VGA 板级测试中使用了 `MMCME2_BASE` 原语生成 25MHz 时钟。其他模块直接使用 100MHz 时钟。

### Phase 3：MicroBlaze 平台搭建（Windows，Vivado + Vitis）

**必须按顺序执行，每步成功后再进下一步。**

#### Step 1：LED 跑马灯
- **目标**：验证 MicroBlaze 能运行 C 代码
- **操作**：见 `platform_test/step1_led_blink/README_manual.md`（手动）或 `README_tcl.md`（脚本）
- **TCL 快速路径**：
  ```tcl
  cd D:/yj_design/project/platform_test/step1_led_blink
  source vivado/create_project.tcl
  source vivado/create_bd.tcl
  ```
  然后 Generate Bitstream → Export Hardware → Launch Vitis → 导入 `sw/main.c` → Run
- **通过标准**：LED[0]→LED[1]→LED[2]→LED[3] 循环闪烁

#### Step 2：UART Hello World
- **目标**：验证串口通信
- **新增**：AXI UART Lite IP（115200 baud，连接板载 FT2232）
- **通过标准**：串口终端（115200, 8N1）显示 "Hello from MicroBlaze!" 和递增计数

#### Step 3：自定义 AXI 外设（键盘）
- **目标**：学会创建自定义 AXI-Lite IP
- **新增**：`ip/kb_periph.v`（AXI-Lite 从设备 + keyboard_scan 例化）
- **通过标准**：按矩阵键盘 → 串口打印 "Key pressed: code=X"
- **重要**：本步是整个项目中最关键的技能点，`README_manual.md` 详细讲解了 Vivado IP 创建和打包流程

#### Step 4：全外设联调
- **目标**：验证 5 个外设全部可通过 AXI 寄存器控制
- **新增**：`ip/fp_payment_periph.v`（完整 AXI-Lite IP，包装全部 5 个模块）
- **通过标准**：C 程序依次测试 LED → 蜂鸣器 → 键盘 → 指纹，串口打印各项结果

### Phase 4：完整系统集成（待实施）

在 Step 4 验证通过后，开发 `system/` 目录下的完整 C 应用代码：
- 主菜单状态机
- 账户管理（开户 / 销户 / 充值 / 查询）
- 支付流程（输入金额 → 指纹认证 → 扣款）
- VGA 界面渲染
- 账户数据存储在 BRAM 中（C 全局数组）

## 五、硬件连接

```
          Nexys4 DDR 开发板
┌──────────────────────────────────────┐
│                                      │
│  VGA 接口 ──── VGA 显示器             │
│  MicroUSB (PROG) ──── PC（供电+串口+下载）│
│                                      │
│  PMOD JB ──── 4×4 矩阵键盘           │
│    JB1-JB4  → 行扫描输出 (Row 0-3)    │
│    JB7-JB10 ← 列读入 (Col 0-3, 上拉) │
│                                      │
│  PMOD JD ──── AS608 指纹传感器        │
│    JD3 (G1) → FPGA TX → 传感器 RXD    │
│    JD4 (G3) ← 传感器 TXD → FPGA RX   │
│    JD5      ─ GND                    │
│    JD6      ─ VCC (3.3V)             │
│                                      │
│  PMOD JC ──── 蜂鸣器模块             │
│    JC4 (G6) → 信号                   │
│    JC5      ─ GND                    │
│    JC6      ─ VCC (3.3V)             │
└──────────────────────────────────────┘
```

## 六、参考文档

| 文档 | 位置 | 内容 |
|------|------|------|
| AS608 通讯手册 | `厂家资料/AS60x指纹识别SOC通讯手册V10.pdf` | UART 协议、指令集、确认码 |
| Nexys4 DDR 参考手册 | `N4.pdf` / `Nexys4ddr_rm.pdf` | 引脚分配、电路原理 |
| 课程任务书 | `2硬件技术课程设计任务书（指纹识别的支付系统）.doc` | 功能需求 |
| 课程指导书 | `2硬件技术课程设计指导书（指纹识别的支付系统）.doc` | 实现参考 |
| 引脚约束（权威源） | `project/shared/nexys4_base.xdc` | 以此文件为准 |
