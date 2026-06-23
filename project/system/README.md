# 完整指纹识别支付系统

目标板卡：Digilent Nexys4 DDR（XC7A100T-1CSG324C），Vivado/Vitis 2022.2。

本目录在 step4 已验证的单个 AXI-Lite 外设基础上集成完整演示系统：MicroBlaze 运行 C 业务状态机，AXI-Lite 外设包装键盘、板载按钮、AS608 指纹、蜂鸣器、LED 和 VGA 字符写口。当前推荐先使用终端版业务验证闭环，VGA 版保留为并行显示版本。

## 目录结构

- `ip/fp_payment_periph.v`：系统版 AXI-Lite 外设，复用 step4 寄存器和 5 个底层模块；VGA 写口改为 toggle 事件，便于跨到 25MHz 像素时钟域。
- `rtl/fp_payment_system_top.v`：完整板级顶层，实例化 `system_bd_wrapper`、VGA MMCM、`vga_ctrl`、`vga_text`。
- `sw/main.c`：VGA UI 版完整 C 应用，包含菜单、账户数据、金额输入、指纹验证/录入、支付扣款、余额查询、自检、VGA/蜂鸣器/LED 反馈。
- `sw_terminal/main.c`：终端 UI 版完整 C 应用，串口显示业务流程，矩阵键盘输入数字和 `A/B/C/D`，`BTNC` 确认，`BTND` 清空/取消。
- `vivado/create_project.tcl`：创建完整 Vivado 工程并生成 Block Design。
- `vivado/create_bd.tcl`：创建 MicroBlaze + UART Lite + 自定义 AXI-Lite 外设 BD。
- `vitis/create_app.tcl`：基于 Vivado 导出的 XSA 创建并编译 Vitis standalone 应用。
- `vitis/create_terminal_app.tcl`：基于 Vivado 导出的 XSA 创建并编译终端 UI standalone 应用。
- `constraints/nexys4_system.xdc`：完整系统板级引脚约束。

## AXI-Lite 寄存器

| 偏移 | 名称 | 方向 | 描述 |
|------|------|------|------|
| `0x00` | `FP_CMD` | W/R | `[31]=start, [23:16]=opcode, [15:0]=param` |
| `0x04` | `FP_RESP` | R | `[31:24]=status, [15:0]=response`；`status`: 0 idle, 1 busy, 2 done, 3 error |
| `0x08` | `KB_DATA` | R | `[4]=valid, [3:0]=key_code`，读后清 valid |
| `0x0C` | `BUZZER` | W | `[2]=fail, [1]=ok, [0]=short`，边沿触发 |
| `0x10` | `VGA_CHAR` | W | `[31]=we, [22:12]=addr, [7:0]=ASCII` |
| `0x14` | `LED` | W/R | `[3:0]=LED` |
| `0x18` | `FP_DBG` | R | 指纹调试: rx_seen/state/tx_idx/rx_cnt/pkt_len/last_rx |
| `0x1C` | `BTN_DATA` | R | `[0]=confirm_valid(BTNC), [1]=clear_valid(BTND)`，读后清 valid |

`fingerprint_ctrl.v` 保持 step4 已验证实现：57600 8N1，首次命令自动执行 3s boot guard、`0x55` wake、1s guard，命令字节间保留 2ms gap。

## 操作流程

键盘映射为常见 4x4 排列：

```text
1 2 3 A
4 5 6 B
7 8 9 C
* 0 # D
```

终端版推荐串口参数：`115200 8N1`。终端只负责显示提示和日志；业务输入仍来自板上硬件。

终端版主菜单：

- `A`：支付。矩阵键盘输入整数金额（单位：元），`BTNC` 确认，`BTND` 清空；随后放置手指，匹配成功后扣除账户余额。
- `B`：余额查询。放置手指，匹配成功后显示账户名、模板 ID 和余额。
- `C`：录入。选择账户 `0-9`，按屏幕提示两次采集指纹，执行 `RegModel` 和 `StoreChar` 写入 AS608 模板库。
- `D`：自检。执行 `VfyPwd`、`ReadSysPara`、`ValidTmplNum`。
- `BTNC`：确认/下一步/返回。
- `BTND`：清空/取消。

终端版不使用矩阵键盘的 `#` 和 `*` 作为确认/清空键；这两个键在终端版业务中会被忽略。

账户数据保存在 MicroBlaze 本地内存中的 `accounts[32]`，演示期间上电保持；默认预置模板 ID 0、1、2 三个账户。录入流程会把选择的账户号作为 AS608 模板页号。

## 构建

Vivado：

```tcl
cd /Users/shen/yunshen/yj_design/project/system
source vivado/create_project.tcl
```

生成 bitstream 后导出硬件（含 bitstream）为 XSA。推荐先构建终端 UI 应用：

```tcl
cd /Users/shen/yunshen/yj_design/project/system
xsct vitis/create_terminal_app.tcl ./fp_payment_system.xsa
```

VGA UI 应用使用：

```tcl
cd /Users/shen/yunshen/yj_design/project/system
xsct vitis/create_app.tcl ./fp_payment_system.xsa
```

如果导出的 XSA 在 Vivado 工程目录中，把实际路径作为脚本第一个参数传入。

## 本地检查

在 `project/` 下可运行：

```bash
iverilog -o /tmp/system_periph.out system/ip/fp_payment_periph.v modules/uart/rtl/uart_tx.v modules/uart/rtl/uart_rx.v modules/keyboard/rtl/keyboard_scan.v modules/fingerprint/rtl/fingerprint_ctrl.v modules/buzzer/rtl/buzzer_ctrl.v
iverilog -o /tmp/vga_check.out modules/vga/rtl/vga_ctrl.v modules/vga/rtl/vga_text.v
```

`fp_payment_system_top.v` 依赖 Vivado 生成的 `system_bd_wrapper` 和 Xilinx `MMCME2_BASE/BUFG` 原语，板级综合请用 Vivado Tcl 工程检查。

## 注意事项

- 不要重写 `modules/fingerprint/rtl/fingerprint_ctrl.v`；它是 step4 AS608 通信已通过的稳定底座。
- 不要整包替换合作者的 `fingerprint/` 目录；系统层只组合现有 opcode。
- 若 AS608 搜索不到模板，先用菜单 `C` 将指纹录入到对应账户页，再执行支付或余额查询。
- 若硬件上 AS608 超时，优先复跑 step4 指纹测试确认接线，再考虑 8N2 A/B 对照。
