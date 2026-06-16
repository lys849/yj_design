# UART 模块板级测试

## 测试目标
验证 UART 收发在真实硬件上工作正常。PC 通过串口发送字节，FPGA 原样返回（回环测试）。

## 硬件连接
仅需 **MicroUSB 数据线** 连接开发板 PROG 口到 PC。板载 FT2232 芯片提供 USB 转串口功能，无需额外接线。

## 源文件清单

在 Vivado 工程中需添加以下文件：

| 文件 | 路径 |
|------|------|
| 测试顶层 | `modules/uart/board_test/uart_test_top.v` |
| UART 发送器 | `modules/uart/rtl/uart_tx.v` |
| UART 接收器 | `modules/uart/rtl/uart_rx.v` |
| 引脚约束 | `modules/uart/board_test/uart_test.xdc` |

## Vivado 操作步骤

### 1. 创建工程
1. 打开 Vivado 2022.2
2. **Create Project** → Project Name: `uart_board_test`
3. Project Type: **RTL Project**
4. **Add Sources** → Add Files → 选择上述 3 个 `.v` 文件
5. **Add Constraints** → Add Files → 选择 `uart_test.xdc`
6. **Default Part** → Parts → 搜索 `xc7a100tcsg324-1` → 选中
7. **Finish**

### 2. 设置顶层模块
1. Sources 面板 → 右键 `uart_test_top` → **Set as Top**

### 3. 生成 Bitstream
1. 左侧 Flow Navigator → **Generate Bitstream**
2. 弹窗确认运行 Synthesis + Implementation → **Yes**
3. 等待 3-5 分钟

### 4. 下载到开发板
1. 用 MicroUSB 连接开发板 PROG 口
2. 打开开发板电源
3. Flow Navigator → **Open Hardware Manager** → **Open Target** → **Auto Connect**
4. **Program Device** → 选择生成的 `.bit` 文件 → **Program**

## 验证方法

### 1. 打开串口终端
- **Windows**: 打开 PuTTY 或 SSCOM
  - 连接方式: Serial
  - 端口: 设备管理器中查找 `COMx`
  - 波特率: **115200**
  - 数据位: 8，停止位: 1，校验: None
- **macOS**: `screen /dev/tty.usbserial-xxx 115200`

### 2. 测试
在串口终端中输入任意字符。

## 预期结果
- 输入的每个字符**立即回显**（你看到每个字符出现两次，一次是本地回显，一次是 FPGA 返回）
- LED[0] 每收到一个字节**翻转一次**
- 如果关闭终端的本地回显功能，输入一个字符应只显示一个（FPGA 返回的）

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 串口终端无反应 | MicroUSB 未连接 PROG 口（不是旁边的 UART 口）|
| 设备管理器找不到 COM 口 | 需安装 FTDI 驱动: https://ftdichip.com/drivers/vcp-drivers/ |
| 收到乱码 | 波特率不是 115200 |
| LED 不亮 | Bitstream 未正确下载——重新 Program Device |
