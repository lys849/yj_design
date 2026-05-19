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

1. 串口工具连接开发板 USB-UART 端口（macOS: `ls /dev/tty.usbserial*` 或 `/dev/cu.usbserial*`）
2. 设置：**115200 baud, 8 data bits, 1 stop bit, no parity**
3. 应看到周期性输出（约每 3 秒一次）：

```
Nexys4 DDR Test OK!
Nexys4 DDR Test OK!
...
```

4. 按 BTNC，立即输出：

```
BTNC pressed!
```

## 故障排查

| 现象               | 可能原因                                                |
|--------------------|--------------------------------------------------------|
| LED 不亮           | 开发板未通电；bitstream 未成功下载；rst_n 被按住           |
| 串口无输出         | 波特率不匹配（需 115200）；串口端口选错；Windows 缺少驱动  |
| LED 不流水         | 时钟未锁定；检查 Vivado 约束是否正确添加                    |
| BTNC 无反应        | 按键定义未加入约束；接触不良                               |
