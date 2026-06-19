# Step 3: 自定义 AXI-Lite 外设 — TCL 脚本指南

## 前置条件
- Vivado + Vitis 已安装（支持 **2022.2** 或 **2025.2**）

## 操作步骤

```tcl
cd D:/Projects/yj_design/project/platform_test/step3_custom_periph
source vivado/create_project.tcl
source vivado/create_bd.tcl
```

脚本使用 **Module Reference** 方式将 `kb_periph.v`（含 AXI-Lite 接口 + 键盘模块）添加到 Block Design。

> **如果 `apply_bd_automation` 报错**（无法识别自定义模块的 AXI 接口），需要改为手动连接——参考 `README_manual.md` 方法二。

然后：Generate Bitstream → Export Hardware。

### Vitis 应用

#### ▸ Vitis 2022.2
**Tools** → **Launch Vitis** → Platform Project（`.xsa`）→ Application Project → 导入 `sw/main.c` → Build → Run

#### ▸ Vitis 2025.2
**Tools** → **Launch Vitis** → New Component → Platform（`.xsa`）→ New Component → Application → 复制 `sw/main.c` → Build → **FLOW** → Run

打开串口终端（115200 baud），按矩阵键盘上的键，应看到 `Key pressed: code=X`。

## 本步核心文件
- `ip/kb_periph.v` — 完整的 AXI-Lite 从设备（无需 Vivado IP 向导）
- `modules/keyboard/rtl/keyboard_scan.v` — 底层键盘扫描模块
