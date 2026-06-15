# Step 3: 自定义 AXI-Lite 外设 — 手动操作指南

## 目标
学习创建自定义 AXI-Lite IP，将键盘模块包装为 MicroBlaze 可访问的外设。按键后 C 代码读取键码并通过串口打印。

## 前置条件
- 已完成 Step 2（理解 MicroBlaze + AXI 基本流程）

---

## 核心概念

MicroBlaze 通过 **AXI 总线** 访问外设。每个外设占用一段地址空间，C 代码通过读写这些地址来控制外设。

```
MicroBlaze → AXI Interconnect → AXI-Lite Slave（自定义 IP）→ keyboard_scan 模块
    C代码写入寄存器地址         总线路由到对应外设         硬件翻译为信号控制
```

我们需要给 `keyboard_scan.v` 模块"穿一件 AXI 外套"——写一个 AXI-Lite 从设备接口，把键盘的输出映射到可读的寄存器上。

---

## 方法一：使用 Vivado 的 IP 创建向导（推荐初学）

### 1. 创建 AXI 外设模板

1. 菜单 **Tools** → **Create and Package New IP**
2. 点击 **Next**
3. 选择 **Create a new AXI4 peripheral** → **Next**
4. 填写信息：
   - **Name**: `kb_periph`
   - **Display name**: `Keyboard Peripheral`
   - **Version**: `1.0`
   - **Repository**: 选择一个文件夹（如工程目录下的 `ip_repo`）
5. **Next**
6. AXI 接口配置：
   - **Interface Name**: `S_AXI`
   - **Interface Type**: `Lite`
   - **Interface Mode**: `Slave`
   - **Data Width**: `32`
   - **Number of Registers**: `4`
7. **Next**
8. 选择 **Edit IP** → **Finish**

Vivado 会打开一个**新的工程窗口**（IP 编辑器），里面有自动生成的模板文件。

### 2. 修改模板代码

在 IP 编辑器中，展开 Sources → Design Sources，找到两个文件：
- `kb_periph_v1_0.v` — 顶层包装
- `kb_periph_v1_0_S_AXI.v` — AXI 从接口实现

**编辑 `kb_periph_v1_0.v`（顶层）**：

在端口列表中添加键盘引脚：
```verilog
// 在模块端口声明中添加:
output wire [3:0] kb_row,
input  wire [3:0] kb_col
```

在内部例化 `kb_periph_v1_0_S_AXI` 的地方，把键盘引脚传递进去：
```verilog
// 在例化语句中添加端口连接:
.kb_row(kb_row),
.kb_col(kb_col)
```

**编辑 `kb_periph_v1_0_S_AXI.v`（AXI 从接口）**：

a) 添加键盘端口：
```verilog
// 在端口声明中添加:
output wire [3:0] kb_row,
input  wire [3:0] kb_col
```

b) 在 `// Add user logic here` 区域添加键盘模块例化：
```verilog
// ---- 用户逻辑 ----
wire [3:0] key_code;
wire       key_valid;

keyboard_scan #(.CLK_FREQ(100_000_000)) u_kb (
    .clk(S_AXI_ACLK),
    .rst_n(S_AXI_ARESETN),
    .row(kb_row),
    .col(kb_col),
    .key_code(key_code),
    .key_valid(key_valid)
);

// 锁存键值，读后自动清零
reg [3:0] latched_code;
reg       latched_valid;

always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        latched_code  <= 4'd0;
        latched_valid <= 1'b0;
    end else begin
        if (key_valid) begin
            latched_code  <= key_code;
            latched_valid <= 1'b1;
        end
        if (axi_arready && S_AXI_ARVALID)
            latched_valid <= 1'b0;
    end
end
```

c) 修改寄存器读取逻辑（找到 `reg_data_out` 的 case 语句）：

将 `2'h0` 分支改为：
```verilog
2'h0: reg_data_out <= {27'd0, latched_valid, latched_code};
```

d) **添加 keyboard_scan.v 源文件到 IP 工程**：
   - 在 IP 编辑器的 Sources 面板 → **Add Sources** → **Add Design Sources**
   - 浏览并添加 `project/modules/keyboard/rtl/keyboard_scan.v`

### 3. 重新打包 IP

1. 在 IP 编辑器中，切换到 **Package IP** 选项卡（底部标签页）
2. 检查各项：
   - **File Groups**: 确认所有 .v 文件已包含
   - **Ports and Interfaces**: 确认 `kb_row` 和 `kb_col` 出现在端口列表
3. 点击 **Review and Package** → **Re-Package IP**
4. 关闭 IP 编辑器窗口

### 4. 在主工程中使用自定义 IP

1. 回到主 Vivado 工程
2. **Settings** → **IP** → **Repository** → **Add** → 选择 `ip_repo` 文件夹
3. 在 Block Design 中：**右键** → **Add IP** → 搜索 `kb_periph` → 双击添加
4. 点击 **Run Connection Automation**，将 `S_AXI` 连接到 MicroBlaze
5. 右键 `kb_row` → **Make External**
6. 右键 `kb_col` → **Make External**

---

## 方法二：使用预写的完整 IP 文件

如果觉得方法一步骤太多，可以直接使用 `ip/kb_periph.v`（已包含完整的 AXI-Lite 接口和键盘逻辑）：

1. 将 `ip/kb_periph.v` 和 `modules/keyboard/rtl/keyboard_scan.v` 添加到工程源文件
2. 在 Block Design 中：**右键** → **Add Module** → 选择 `kb_periph`
3. 连接 AXI 接口和外部引脚

这种方式更快但不使用 Vivado 的 IP 打包机制。

---

## XDC 约束

确保 XDC 中包含键盘 PMOD JB 引脚（见 `create_project.tcl` 中的约束内容）。

---

## Vitis 应用

创建方式同 Step 2，将 `sw/main.c` 导入工程。

关键代码说明：
```c
// 读取键盘寄存器
u32 kb_data = Xil_In32(KB_PERIPH_BASE + 0x00);
u32 valid   = (kb_data >> 4) & 0x1;  // bit[4] = key_valid
u32 code    = kb_data & 0xF;         // bit[3:0] = key_code
```

> **注意**: `KB_PERIPH_BASE` 的值由 Vivado 自动分配，定义在 Vitis 生成的 `xparameters.h` 中。

---

## 预期结果
串口终端显示：
```
Step 3: Keyboard Peripheral Test
Press keys on 4x4 keypad...

Key pressed: code=0
Key pressed: code=5
Key pressed: code=15
```
同时 LED 显示最后按下的键码（二进制）。

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 编译报找不到 keyboard_scan | IP 工程未添加 keyboard_scan.v 源文件 |
| Validate Design 报 AXI 接口错误 | AXI 端口命名不规范——检查大小写和前缀是否为 S_AXI_ |
| C 代码编译报 BASEADDR 未定义 | `xparameters.h` 中没有自定义 IP 的条目——检查 IP 是否在 BD 中正确连接 |
| 按键无反应 | PMOD JB 接线顺序错误；XDC 引脚映射不对 |
