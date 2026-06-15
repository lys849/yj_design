# Step 4: 全外设联调 — TCL 脚本指南

## 操作步骤

```tcl
# Windows Vivado TCL Console（用正斜杠，替换为你的实际路径）:
cd D:/yj_design/project/platform_test/step4_all_periph
source vivado/create_project.tcl
source vivado/create_bd.tcl
```

然后：Generate Bitstream → Export Hardware → Launch Vitis → 导入 `sw/main.c` → Build → Run。

## 硬件连接
- **PMOD JB**: 4×4 矩阵键盘
- **PMOD JD**: AS608 指纹传感器（JD3=TX, JD4=RX, JD5=GND, JD6=VCC）
- **PMOD JC**: 蜂鸣器（JC4=信号, JC5=GND, JC6=VCC）
- **MicroUSB**: PROG 口（供电 + 下载 + 串口）

打开串口终端（115200 baud），程序自动依次测试 LED → 蜂鸣器 → 键盘 → 指纹传感器。

详细寄存器映射和故障排查见 `README_manual.md`。
