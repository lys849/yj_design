# Step 2: UART Hello World — 手动操作指南

## 目标
在 Step 1 基础上添加 AXI UART Lite，通过串口终端看到 MicroBlaze 输出的文字。

## 前置条件
- 已完成 Step 1（理解 Block Design 基本流程）

---

## 与 Step 1 的差异
在 Step 1 的 Block Design 基础上，仅增加两个操作：
1. 添加 AXI UART Lite IP
2. 引出 UART TX/RX 端口

如果你希望从头操作，先按 Step 1 的步骤 2.1—2.6 完成基础 Block Design，然后继续以下步骤。

---

## 新增步骤：添加 AXI UART Lite

### 1. 添加 IP
1. 在 Diagram 中 **右键** → **Add IP** → 搜索 `AXI UART Lite` → 双击添加
2. **双击** `axi_uartlite_0` 进行配置：
   - **Baud Rate**: `115200`
   - 其余保持默认
   - 点击 **OK**

### 2. 自动连线
1. 点击顶部绿色横幅 **Run Connection Automation**
2. 选中 `/axi_uartlite_0/S_AXI`
3. Master 选择 `/microblaze_0 (Periph)`
4. 点击 **OK**

### 3. 引出 UART 端口
1. 右键 `axi_uartlite_0` 的 **tx** 引脚 → **Make External** → 重命名为 `uart_tx`
2. 右键 `axi_uartlite_0` 的 **rx** 引脚 → **Make External** → 重命名为 `uart_rx`

### 4. 更新约束文件
在 XDC 中添加两行（D4 = FPGA→PC，C4 = PC→FPGA）：
```
set_property PACKAGE_PIN D4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PACKAGE_PIN C4 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
```

### 5. 验证、生成、下载
按 Step 1 的第三—七部分操作（Validate → Bitstream → Export → Vitis → Build → Run）。

---

## 串口终端设置

下载程序后，需要打开串口终端才能看到输出：

### 方法 1: Vitis 内置终端
1. Vitis 菜单 → **Window** → **Show View** → **Terminal**
2. 点击绿色 **+** 号 → **Connect**
3. 参数：
   - Port: 在设备管理器中找 `COMx`（或 macOS: `/dev/tty.usbserial-xxx`）
   - Baud Rate: `115200`
   - Data Bits: `8`，Stop Bits: `1`，Parity: `None`

### 方法 2: 第三方工具
- Windows: PuTTY（选 Serial 模式）或 SSCOM
- macOS: `screen /dev/tty.usbserial-xxx 115200`

---

## 预期结果
串口终端显示：
```
==============================
 Hello from MicroBlaze!
 Nexys4 DDR - Step 2 UART Test
==============================

Count: 0
Count: 1
Count: 2
...
```
同时 LED 以二进制计数方式变化。

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 串口无输出 | 波特率不是 115200；串口端口选错；MicroUSB 未连 PROG 口 |
| 乱码 | 波特率不匹配——确认 IP 配置和终端设置均为 115200 |
| LED 不亮但串口正常 | XDC 中 LED 端口名与 BD 不匹配 |
