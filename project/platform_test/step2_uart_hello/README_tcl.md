# Step 2: UART Hello World — TCL 脚本指南

## 操作步骤

```tcl
# Windows Vivado TCL Console（用正斜杠，替换为你的实际路径）:
cd D:/yj_design/project/platform_test/step2_uart_hello
source vivado/create_project.tcl
source vivado/create_bd.tcl
```

然后：Generate Bitstream → Export Hardware → Launch Vitis → 创建应用 → 导入 `sw/main.c` → Build → Run。

打开串口终端（115200 baud），应看到 "Hello from MicroBlaze!" 和递增计数。

详细的 Vitis 操作和串口设置见 `README_manual.md`。
