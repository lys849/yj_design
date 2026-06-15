# Step 1: LED 跑马灯 — TCL 脚本指南

## 目标
与手动操作版相同：MicroBlaze + LED 跑马灯。使用 TCL 脚本自动完成工程创建和 Block Design 搭建。

## 前置条件
- Vivado 2022.2 + Vitis 2022.2 已安装
- Nexys4 DDR 开发板

---

## 操作步骤

### 1. 打开 Vivado，进入工作目录
打开 Vivado 2022.2，在底部 **Tcl Console** 中输入（用正斜杠，替换为你的实际路径）：
```tcl
cd D:/yj_design/project/platform_test/step1_led_blink
```

### 2. 执行工程创建脚本
```tcl
source vivado/create_project.tcl
```
脚本会自动创建 Vivado 工程并添加 XDC 约束。

### 3. 执行 Block Design 创建脚本
```tcl
source vivado/create_bd.tcl
```
脚本会自动完成：
- 添加 MicroBlaze（128KB BRAM + 调试模块）
- 添加 Clocking Wizard（100MHz）
- 添加复位反相器（适配 Nexys4 DDR 的低有效复位）
- 添加 AXI GPIO（4-bit LED 输出）
- 自动连线、验证设计、生成 HDL Wrapper

完成后在 Diagram 窗口可以看到完整的连线图。

### 4. 生成 Bitstream
左侧 **Flow Navigator** → **Generate Bitstream** → 确认运行 Synthesis 和 Implementation → 等待 3-10 分钟。

### 5. 导出硬件 + 启动 Vitis
1. **File** → **Export Hardware** → 勾选 **Include bitstream** → **Finish**
2. **Tools** → **Launch Vitis IDE**

### 6. 创建 Vitis 应用
1. **File** → **New** → **Platform Project** → 选择导出的 `.xsa` 文件
2. **File** → **New** → **Application Project** → 选 **Empty Application**
3. 将 `sw/main.c` 导入到应用工程的 `src/` 目录
4. **Build Project**

### 7. 下载运行
1. MicroUSB 连接开发板 PROG 口
2. **Xilinx** → **Program FPGA**
3. **Run As** → **Launch on Hardware**

---

## 预期结果
LED[0] → LED[1] → LED[2] → LED[3] 依次点亮，周期 200ms。

## TCL 脚本说明
如需了解脚本做了什么，可打开 `vivado/create_bd.tcl` 查看注释，或对照 `README_manual.md` 的手动步骤。
