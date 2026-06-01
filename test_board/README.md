# Fingerprint Payment System — 板级自检测试

## 目的

无需 VGA 显示器，通过串口终端完整验证支付系统全部外设功能。

## 测试外设

| 外设 | 连接 | PMOD | 测试方式 |
|------|------|------|----------|
| 键盘 4×4 | JB | — | 菜单选择、金额输入 |
| 指纹传感器 AS608 | JD | — | 注册、识别、支付验证 |
| 蜂鸣器 | JC | — | 按键短鸣、成功/失败提示 |
| 串口输出 | MicroUSB | — | 显示菜单、金额、状态 |

## 串口连接（首选：Vitis Serial Terminal）

### Windows 11 — Vitis Serial Terminal

1. 开始菜单搜索 **Vitis 2022.2** 并打开（无需创建工程）
2. 菜单栏 → **Window → Show View → Terminal**
3. Terminal 面板点击绿色 + 号 → **Connect**
4. 参数设置：
   - Port: 设备管理器中的 `COMx`
   - Baud Rate: `115200`
   - Data Bits: `8`
   - Stop Bits: `1`
   - Parity: `None`
   - Flow Control: `None`

### 替代方案

| 工具 | 说明 |
|------|------|
| 串口调试助手（SSCOM 等） | 国内常用，小巧便捷 |
| PuTTY | 免费，选择 Serial 模式 |
| macOS: `screen /dev/tty.usbserial-xxx 115200` | 内置命令 |

### 驱动安装

若设备管理器未出现 USB Serial Port，下载 FTDI 驱动：https://ftdichip.com/drivers/vcp-drivers/

## 文件说明

```
test_board/
├── rtl/
│   ├── test_board.v   # 完整支付系统状态机
│   └── msg_rom.v      # 消息 ROM（生成文件，非手动维护）
├── tb/
│   └── test_board_tb.v
├── test_board.xdc     # 引脚约束
└── README.md
```

复用 `demo/rtl/` 下的模块：`uart_tx.v`、`keyboard_scan.v`、`fingerprint_ctrl.v`、`uart_rx.v`、`buzzer_ctrl.v`

## Vivado 操作步骤

### 1. 创建工程

- 打开 Vivado 2022.2
- Create Project → RTL Project
- 不勾选 "Do not specify sources at this time"
- 选择 Board: **Nexys4 DDR**
  - 如无 Boards 选项卡，手动选 Family: Artix-7, Package: csg324, Speed: -1, Part: xc7a100tcsg324-1

### 2. 添加源文件

Flow Navigator → **Add Sources** → 添加：
- `demo/test_board/rtl/test_board.v`
- `demo/rtl/uart_tx.v`
- `demo/rtl/uart_rx.v`
- `demo/rtl/keyboard_scan.v`
- `demo/rtl/fingerprint_ctrl.v`
- `demo/rtl/buzzer_ctrl.v`

右键 `test_board` → **Set as Top**

### 3. 添加约束文件

- Add Sources → Add or create constraints
- 添加 `demo/test_board/test_board.xdc`

### 4. 生成 Bitstream

Flow Navigator → **Generate Bitstream** → 等待完成（3-5 分钟）

### 5. 下载到开发板

1. MicroUSB 连接开发板 PROG 口
2. 开发板上电
3. Open Hardware Manager → Open Target → Auto Connect
4. Program Device → 选择 `.bit` 文件

## 串口终端预期输出

### 启动

```
=== FINGERPRINT PAYMENT SYSTEM ===
FP Sensor: OK

[MAIN]
 1.Account  2.Payment
>
```

> 若看到 `FP Sensor: FAIL`，检查指纹传感器接线和供电。系统仍可测试键盘和蜂鸣器。

### 按键映射

| 键 | 功能 |
|----|------|
| 0-9 | 数字输入 |
| A | 确认 |
| B | 取消 / 返回上级菜单 |
| F | 退格 / 清除输入 |

### 主菜单操作

按 **1** → 进入账户管理：
```
[ACCOUNT]
 1.Create  2.Delete
 3.Recharge  4.Query
 B:Back
>
```

按 **2** → 进入支付：
```
PAYMENT
Enter amount (yuan):
```

### 创建账户流程

1. 选择 1.Create
2. 提示 `Place finger (1/2)...` — 在传感器上放手指
3. 提示 `Place finger (2/2), press A...` — 再次放手指，按 A
4. 提示 `Enter deposit (yuan):` — 输入金额，按 A 确认
5. 显示 `Account created!`

### 支付流程

1. 主菜单按 **2**
2. 输入金额（如 `1250` = ¥12.50），按 **A**
3. 提示 `Place finger to confirm...`
4. 放手指 → 自动识别 → 扣款
5. 显示 `Payment successful!`

### 蜂鸣器反馈

| 事件 | 蜂鸣 |
|------|------|
| 按键按下 | 短蜂鸣 |
| 操作成功 | 长蜂鸣 |
| 操作失败 | 双蜂鸣 |

## 预置测试账户

| 槽位 | 指纹 ID | 余额 |
|------|---------|------|
| 1 | fp_id=1 | ¥100.00 |
| 2 | fp_id=2 | ¥50.00 |

> 需要先通过「创建账户」功能向 AS608 录入指纹（对应 fp_id 1 和 2），之后支付和账户管理才能正常匹配。

## iverilog 仿真

```bash
cd demo
iverilog -o test_board/tb/test_board_tb.out \
    test_board/tb/test_board_tb.v \
    test_board/rtl/test_board.v \
    rtl/uart_tx.v rtl/uart_rx.v rtl/keyboard_scan.v \
    rtl/fingerprint_ctrl.v rtl/buzzer_ctrl.v \
    && vvp test_board/tb/test_board_tb.out
```

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 串口无输出 | 波特率不是 115200；串口端口选错；FTDI 驱动未安装 |
| 键盘无反应 | PMOD JB 接线顺序错误；键盘排线松动 |
| FP Sensor: FAIL | 传感器未接线或接线反了；传感器未供电 |
| 指纹不匹配 | score 阈值需 >80；手指偏湿或偏干；需要重新录入 |
