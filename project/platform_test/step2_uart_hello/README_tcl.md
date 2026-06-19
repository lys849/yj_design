# Step 2: UART Hello World — TCL 脚本指南

## 前置条件
- Vivado + Vitis 已安装（支持 **2022.2** 或 **2025.2**）

## 操作步骤

```tcl
cd D:/Projects/yj_design/project/platform_test/step2_uart_hello
source vivado/create_project.tcl
source vivado/create_bd.tcl
```

然后：Generate Bitstream → Export Hardware。

### Vitis 应用

#### ▸ Vitis 2022.2
1. **Tools** → **Launch Vitis IDE** → 设置 Workspace
2. **File** → **New** → **Platform Project** → 选择 `.xsa` → Build
3. **File** → **New** → **Application Project** → **Empty Application** → 导入 `sw/main.c` → Build → Run

#### ▸ Vitis 2025.2
1. **Tools** → **Launch Vitis IDE** → 设置 Workspace
2. **File** → **New Component** → **Platform** → 选择 `.xsa`，`standalone`/`microblaze_0` → Build
3. **File** → **New Component** → **Application** → **Empty Application (C)** → 复制 `sw/main.c` → Build
4. **FLOW** 面板 → **Program Device** → **Run**

打开串口终端（115200 baud），应看到 "Hello from MicroBlaze!" 和递增计数。

详细的 Vitis 操作和串口设置见 `README_manual.md`。
