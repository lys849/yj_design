# Step 1: LED 跑马灯 — 手动操作指南

## 目标
验证 MicroBlaze 软核处理器能在 Nexys4 DDR 上正常运行。LED 以跑马灯方式闪烁。

## 前置条件
- Vivado 2022.2 已安装
- Vitis 2022.2 已安装
- Nexys4 DDR 开发板 + MicroUSB 数据线

---

## 第一部分：创建 Vivado 工程

1. 打开 **Vivado 2022.2**
2. 点击 **Create Project**
3. 点击 **Next**
4. **Project Name**: `step1_led_blink`，选择一个工作目录，点击 **Next**
5. **Project Type**: 选择 `RTL Project`，**不要**勾选 "Do not specify sources at this time"，点击 **Next**
6. **Add Sources**: 不添加任何文件，直接点击 **Next**
7. **Add Constraints**: 不添加，直接点击 **Next**
8. **Default Part**:
   - 点击上方 **Boards** 选项卡
   - 搜索 `Nexys4 DDR`
   - 选中后点击 **Next**
   - 如果找不到 Boards，切换到 **Parts** 选项卡，Family 选 `Artix-7`，Package 选 `csg324`，Speed 选 `-1`，找到 `xc7a100tcsg324-1`
9. 点击 **Finish**

---

## 第二部分：创建 Block Design

### 2.1 新建 Block Design
1. 左侧 **Flow Navigator** → **IP INTEGRATOR** → **Create Block Design**
2. Design name 输入 `system`，点击 **OK**
3. 出现空白的 **Diagram** 窗口

### 2.2 添加 MicroBlaze
1. 在 Diagram 空白处 **右键** → **Add IP**（或点击上方 + 号）
2. 搜索 `MicroBlaze`，双击添加
3. 此时 Diagram 中出现 MicroBlaze 模块

### 2.3 运行 Block Automation
1. Diagram 顶部出现绿色横幅 **Run Block Automation** → **点击它**
2. 弹出配置窗口，按如下设置：
   - **Local Memory**: `128KB`
   - **Cache Configuration**: `None`
   - **Debug Module**: `Debug Only`
   - **Peripheral AXI Port**: `Enabled`
   - **Clock Connection**: `New Clocking Wizard (100 MHz)`
   - 其余保持默认
3. 点击 **OK**
4. 等待自动化完成，Diagram 中自动出现：
   - `clk_wiz_1`（时钟向导，100MHz 输入→100MHz 输出）
   - `rst_clk_wiz_1_100M`（复位模块）
   - `dlmb_v10` / `ilmb_v10`（本地内存总线）
   - `lmb_bram`（128KB BRAM）
   - `mdm_1`（调试模块）

### 2.4 修正复位极性
Nexys4 DDR 的 CPU_RESET 按钮是**低有效**（按下=0），但复位模块期望**高有效**输入。需要加一个反相器：

1. **右键** → **Add IP** → 搜索 `Utility Vector Logic` → 双击添加
2. **双击** 新添加的 `util_vector_logic_0` 进行配置：
   - **C_SIZE**: `1`
   - **C_OPERATION**: `not`
   - 点击 **OK**
3. 找到 Diagram 中标记 `reset`（或 `ext_reset_in`）的外部端口
4. **删除** `reset` 外部端口到 `rst_clk_wiz_1_100M/ext_reset_in` 的连线（选中连线，按 Delete）
5. **删除** `reset` 外部端口本身（选中端口，按 Delete）
6. 右键 `util_vector_logic_0` 的 **Op1** 引脚 → **Make External** → 端口会自动命名为 `Op1_0`
7. **双击** 外部端口 `Op1_0` 重命名为 `reset_n`
8. **手动连线**: 将 `util_vector_logic_0` 的 **Res** 输出连接到 `rst_clk_wiz_1_100M` 的 **ext_reset_in** 输入
   - 鼠标从 Res 引脚拖到 ext_reset_in 引脚

### 2.5 添加 AXI GPIO
1. **右键** → **Add IP** → 搜索 `AXI GPIO` → 双击添加
2. **双击** `axi_gpio_0` 进行配置：
   - **GPIO Width**: `4`
   - 勾选 **All Outputs**
   - 点击 **OK**
3. Diagram 顶部出现绿色横幅 **Run Connection Automation** → **点击它**
4. 确认 `/axi_gpio_0/S_AXI` 被选中
5. **Master**: 应显示 `/microblaze_0 (Periph)`
6. 点击 **OK**
7. 自动创建 AXI Interconnect 并完成连接

### 2.6 引出 LED 端口
1. 找到 `axi_gpio_0` 的 **gpio_io_o** 输出端口
2. **右键** → **Make External**
3. **双击** 外部端口重命名为 `led`

### 2.7 检查时钟输入
1. 找到 `clk_wiz_1` 的 **clk_in1** 输入端口
2. 确认它已连接到外部端口（应该叫 `sys_clock` 或 `clk_in1_0`）
3. 如果端口名不是 `sys_clock`，**双击**重命名为 `sys_clock`

### 2.8 验证设计
1. 菜单栏 → **Tools** → **Validate Design**（或按 **F6**）
2. 应显示绿色对话框 **"Validation successful"**
3. 如果有错误/警告，根据提示修正连线
4. **Ctrl+S** 保存 Block Design

---

## 第三部分：添加引脚约束

1. **Sources** 面板 → **Add Sources**（或菜单 File → Add Sources）
2. 选择 **Add or create constraints** → **Next**
3. **Create File** → 文件名 `nexys4_step1` → **OK** → **Finish**
4. 在 Sources → Constraints → `nexys4_step1.xdc` 上 **双击** 打开
5. 粘贴以下内容（根据你的外部端口名称调整）：

```
set_property PACKAGE_PIN E3 [get_ports sys_clock]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clock]
create_clock -period 10.000 -name sys_clk [get_ports sys_clock]

set_property PACKAGE_PIN C12 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]

set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
```

> **注意**: `sys_clock`、`reset_n`、`led` 必须与 Block Design 中外部端口的名称**完全一致**。如果你的端口名不同（如 `clk_in1_0`），需要相应修改 XDC。

---

## 第四部分：生成 Bitstream

1. **Sources** 面板 → 右键 `system_wrapper` → **Set as Top**（如果还没设置）
2. 左侧 **Flow Navigator** → **PROGRAM AND DEBUG** → **Generate Bitstream**
3. 弹窗问是否先运行 Synthesis 和 Implementation → 选 **Yes**
4. Launch Runs 对话框 → 选择 CPU 核心数 → **OK**
5. 等待 **3-10 分钟**（取决于电脑性能）
6. 完成后弹窗选择 **Open Hardware Manager** 或 **View Reports** → 先选 **Cancel**

---

## 第五部分：导出硬件 + 启动 Vitis

1. 菜单 **File** → **Export Hardware**
2. 勾选 **Include bitstream** → **Next** → **Finish**
   - 导出的 `.xsa` 文件位于工程目录下
3. 菜单 **Tools** → **Launch Vitis IDE**
4. Workspace 选择一个空文件夹（如工程目录下新建 `vitis_workspace`）

---

## 第六部分：创建 Vitis 应用

### 6.1 创建平台工程
1. **File** → **New** → **Platform Project**
2. Platform project name: `step1_platform`
3. 选择 **Create from XSA** → 浏览到刚才导出的 `.xsa` 文件
4. **Finish**
5. 等待平台工程构建完成

### 6.2 创建应用工程
1. **File** → **New** → **Application Project**
2. 点击 **Next**
3. 选择刚创建的平台 `step1_platform` → **Next**
4. Application project name: `step1_app` → **Next**
5. Domain 保持默认 → **Next**
6. Template 选择 **Empty Application** → **Finish**

### 6.3 添加源代码
1. 展开 `step1_app` → `src` 文件夹
2. 右键 `src` → **Import Sources**
3. 浏览到 `platform_test/step1_led_blink/sw/` → 选择 `main.c`
4. 或者：右键 `src` → **New** → **File** → 命名 `main.c`，然后把 `sw/main.c` 的内容粘贴进去

### 6.4 编译
1. 右键 `step1_app` → **Build Project**
2. 等待编译完成（Console 应显示 "Build Finished"）

---

## 第七部分：下载到开发板

1. 用 MicroUSB 数据线连接 Nexys4 DDR 的 **PROG** 口到电脑
2. 打开开发板电源
3. 在 Vitis 中：**Xilinx** → **Program FPGA** → 选择 bitstream → **Program**
4. 右键 `step1_app` → **Run As** → **Launch on Hardware (Single Application Debug)**

---

## 预期结果
- LED[0] → LED[1] → LED[2] → LED[3] 依次点亮，形成跑马灯效果
- 每个 LED 亮约 200ms
- 按 CPU_RESET 按钮可复位（LED 从 LED[0] 重新开始）

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| Generate Bitstream 报错 | XDC 端口名与 Block Design 不匹配——检查大小写和端口名 |
| 编译报 `xparameters.h` 找不到 | 平台工程未正确构建——右键平台工程 → Build |
| 下载后 LED 不亮 | 检查 MicroUSB 是否连接的 PROG 口（不是 UART 口）|
| LED 全亮不闪烁 | 程序可能在 usleep 处卡住——检查 BSP 中 sleep 驱动是否启用 |
