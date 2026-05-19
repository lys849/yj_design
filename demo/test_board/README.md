# Nexys4 DDR 开发板自检测试

## 目的

在外设（指纹传感器、键盘、蜂鸣器、VGA 显示器）到货前，先验证开发板本身工作正常。

## 测试内容

| 测试项   | 板载资源        | 预期现象                                         |
|----------|-----------------|--------------------------------------------------|
| LED      | 4 个用户 LED    | 上电后流水灯；按 BTNC 切换 4 种图案                |
| 串口     | USB-UART 桥     | 串口终端周期性输出 "Nexys4 DDR Test OK!"          |
| 按键     | BTNC 中心按键   | 按 BTNC 切换 LED 图案，串口打印 "BTNC pressed!"    |

## 文件说明

```
test_board/
├── rtl/
│   └── test_board.v       # 自检顶层模块
├── tb/
│   └── test_board_tb.v    # 仿真测试台
├── test_board.xdc         # 引脚约束
└── README.md              # 本文件
```

> `test_board.v` 复用 `demo/rtl/uart_tx.v`，Vivado 需同时添加该文件。

## 步骤 1：iverilog 仿真（可选，先验证逻辑）

```bash
cd demo
iverilog -o tb/test_board_tb.out \
    test_board/tb/test_board_tb.v \
    test_board/rtl/test_board.v \
    rtl/uart_tx.v \
    && vvp tb/test_board_tb.out
```

预期输出: LED 信号在波形中可见；UART 输出 "Nexys4 DDR Test OK!" 后周期性重复。

## 步骤 2：创建 Vivado 工程

1. 打开 Vivado 2022.2
2. **Create Project** → Next
3. Project name: `test_board`，路径自定义
4. Project Type: **RTL Project** → 勾选 "Do not specify sources at this time"
5. Device: **Boards** → 搜索 "Nexys4 DDR"  → 选择 → Next → Finish
   > 如无 Boards 选项卡，手动选：Family: Artix-7, Package: csg324, Speed: -1, Part: xc7a100tcsg324-1

## 步骤 3：添加源文件

1. 左侧 Flow Navigator → **Add Sources** → Add or create design sources
2. 添加以下文件：
   - `demo/test_board/rtl/test_board.v`
   - `demo/rtl/uart_tx.v`
3. 确保 `test_board` 为 **Top Module**（Sources 面板右键 → Set as Top）

## 步骤 4：添加约束文件

1. **Add Sources** → Add or create constraints
2. 添加 `demo/test_board/test_board.xdc`

## 步骤 5：生成 Bitstream

1. 左侧 Flow Navigator → **Generate Bitstream**
2. 若提示无 Implementation，点击 **Yes** 自动运行综合与实现
3. 等待完成（约 3-5 分钟）

## 步骤 6：下载到开发板

1. 用 MicroUSB 线连接开发板 **PROG 口** 至电脑
2. 开发板上电（POWER 开关拨到 ON）
3. Vivado → **Open Hardware Manager** → Open Target → Auto Connect
4. 右键目标器件 → **Program Device** → 选择生成的 `.bit` 文件 → Program

## 步骤 7：验证

### LED 检查

上电后 4 个 LED 依次向左流水（LD0→LD1→LD2→LD3→LD0...）。按 **BTNC**（C12 旁边的大按键）切换 LED 图案：

| 按 BTNC 次数 | LED 图案              |
|-------------|----------------------|
| 0（默认）    | 向左流水灯            |
| 1           | 向右流水灯            |
| 2           | 全亮/全灭交替          |
| 3           | 二进制计数            |
| 4           | 回到向左流水灯         |

### 串口检查

Nexys4 DDR 板载 FT2232HQ USB-UART 桥接芯片，通过 MicroUSB 线连接到电脑后会生成一个虚拟串口。

#### Windows 11 串口设置

**1. 确认串口号**

- 右键「开始」菜单 → **设备管理器**
- 展开 **端口 (COM 和 LPT)**
- 查找 **USB Serial Port (COMx)**，记住 `COMx` 编号（如 COM3、COM4）
- 如果没有出现该设备，说明缺少 FTDI 驱动，参见下方「驱动安装」

**2. 串口终端推荐**

以下任选一个：

| 工具 | 说明 |
|------|------|
| **PuTTY** | 免费，下载 [putty.org](https://www.putty.org)，选择 Serial 模式 |
| **MobaXterm** | 免费版够用，串口功能直观 |
| **串口调试助手** | 国内常用，如 SSCOM、友善串口助手等 |

**3. 连接参数**

无论用哪个工具，参数统一设置为：

- **波特率 (Baud Rate):** 115200
- **数据位 (Data Bits):** 8
- **停止位 (Stop Bits):** 1
- **校验位 (Parity):** None
- **流控 (Flow Control):** None

**4. 以 PuTTY 为例的操作步骤**

1. 打开 PuTTY，左侧选择 **Session**
2. Connection type 选 **Serial**
3. Serial line 填入设备管理器中看到的 `COMx`（如 `COM3`）
4. Speed 填 `115200`
5. 左侧 Category → **Serial**，确认参数：
   - Data bits: 8
   - Stop bits: 1
   - Parity: None
   - Flow control: None
6. 点击 **Open** 打开串口
7. 开发板上电 / 按 PROG 重新下载 bitstream 后，应看到周期性输出（约每 3 秒一次）：

```
Nexys4 DDR Test OK!
Nexys4 DDR Test OK!
...
```

8. 按 **BTNC** 按键，立即输出：

```
BTNC pressed!
```

> 如果串口窗口显示乱码，检查波特率是否为 **115200**（常见错误是设成了 9600）。

#### 驱动安装

如果设备管理器中未出现 USB Serial Port，或显示带黄色感叹号的设备：

1. 打开 [FTDI 驱动下载页](https://ftdichip.com/drivers/vcp-drivers/)
2. 下载 Windows 版本（通常为 setup executable）
3. 安装后重新插拔 MicroUSB 线
4. 设备管理器应出现 **USB Serial Port (COMx)**

#### macOS 串口设置

1. 终端执行 `ls /dev/tty.usbserial*` 找到串口设备
2. 使用 `screen` 连接：`screen /dev/tty.usbserial-xxxx 115200`
3. 退出：`Ctrl+A` 然后 `K`，回答 `y`

## 故障排查

| 现象               | 可能原因                                                |
|--------------------|--------------------------------------------------------|
| LED 不亮           | 开发板未通电；bitstream 未成功下载；rst_n 被按住           |
| 串口无输出         | 波特率不匹配（需 115200）；串口端口选错；Windows 缺少驱动  |
| LED 不流水         | 时钟未锁定；检查 Vivado 约束是否正确添加                    |
| BTNC 无反应        | 按键定义未加入约束；接触不良                               |
