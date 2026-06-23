# 完整系统交接记录

## 本轮完成

- 基于 `platform_test/step4_all_periph/ip/fp_payment_periph.v` 创建系统版 AXI-Lite 外设，寄存器映射保持兼容。
- 增加板载按钮输入 `BTNC/BTND`，新增 `BTN_DATA(0x1C)` 读后清事件寄存器；`BTNC` 确认，`BTND` 清空/取消。
- 增加 `rtl/fp_payment_system_top.v`，将 MicroBlaze BD 的 VGA 字符写口接到 `vga_ctrl`/`vga_text`。
- 增加完整 C 应用 `sw/main.c`：
  - 主菜单：支付、余额查询、指纹录入、自检。
  - 账户表：32 个账户，演示期保存在 MicroBlaze 本地内存。
  - 支付：金额输入、指纹 `GetImage -> GenChar -> Search`、余额扣款。
  - 录入：两次采集、`RegModel`、`StoreChar`。
  - VGA、蜂鸣器、LED 反馈。
- 增加终端 UI 完整 C 应用 `sw_terminal/main.c`：
  - 串口显示完整业务流程，115200 8N1。
  - 矩阵键盘只输入数字和 `A/B/C/D`。
  - `BTNC` 替代 `#`，`BTND` 替代 `*`。
- 增加 Vivado Tcl：`vivado/create_project.tcl`、`vivado/create_bd.tcl`。
- 增加 Vitis/XSCT Tcl：`vitis/create_app.tcl`、`vitis/create_terminal_app.tcl`。
- 增加完整系统 XDC：`constraints/nexys4_system.xdc`。
- 补齐 `vga_text.v` 中系统菜单需要的大写字母字模。

## 保持不变

- 未重写 `project/modules/fingerprint/rtl/fingerprint_ctrl.v`。
- 未整包替换合作者 `fingerprint/` 目录。
- AS608 仍使用 step4 已验证的 57600 8N1、自动 boot/wake guard、2ms 字节间隔。

## 上板建议

1. 在 Vivado 中运行：

   ```tcl
   cd /Users/shen/yunshen/yj_design/project/system
   source vivado/create_project.tcl
   ```

2. Generate Bitstream，导出含 bitstream 的 XSA。
3. 推荐先用 XSCT/Vitis 构建终端 UI 应用：

   ```tcl
   xsct vitis/create_terminal_app.tcl /path/to/fp_payment_system.xsa
   ```

4. 串口终端设置为 115200 8N1。上板后按矩阵键盘 `D` 做 AS608 自检，按 `BTNC` 返回。
5. 若模板库为空，按 `C` 录入账户 0/1/2，再按 `A` 支付或 `B` 查余额。

## 待硬件确认

- Vivado 2022.2 中 `vitis/create_app.tcl` 的 domain 名称通常为 `standalone_domain`；若本机 Vitis 生成了不同 domain 名，需在脚本中调整 `app create -domain`。
- `vitis/create_terminal_app.tcl` 使用同样的 domain 假设。
- VGA 写口采用 toggle 跨时钟，C 代码逐字符 AXI 写入，正常人机菜单速度下有充足间隔；若后续改成高速刷屏，可在外设侧增加 FIFO。
