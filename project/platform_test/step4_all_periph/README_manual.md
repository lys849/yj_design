# Step 4: 全外设联调 — 手动操作指南

## 目标
将全部 5 个外设（键盘、指纹、蜂鸣器、LED、VGA 字符写入）包装在单个 AXI-Lite IP 中，MicroBlaze 逐一测试。

## 前置条件
- 已完成 Step 3（理解自定义 AXI-Lite IP 工作流程）
- Vivado + Vitis 已安装（支持 **2022.2** 或 **2025.2**）

---

## 与 Step 3 的差异
- 自定义 IP 从 `kb_periph`（仅键盘）扩展为 `fp_payment_periph`（全部模块）
- 需要添加更多源文件（uart_tx/rx、fingerprint_ctrl、buzzer_ctrl）
- 需要引出更多外部端口（指纹 JD、蜂鸣器 JC）

## 操作步骤

### 1. 创建工程
按 Step 1 方式创建新工程 `step4_all_periph`，添加以下源文件：
- `platform_test/step4_all_periph/ip/fp_payment_periph.v`
- `modules/uart/rtl/uart_tx.v`
- `modules/uart/rtl/uart_rx.v`
- `modules/keyboard/rtl/keyboard_scan.v`
- `modules/fingerprint/rtl/fingerprint_ctrl.v`
- `modules/buzzer/rtl/buzzer_ctrl.v`

### 2. Block Design
按 Step 2 方式创建基础系统（MicroBlaze + GPIO + UART），然后：
1. **右键** → **Add Module** → 选择 `fp_payment_periph`
2. **Run Connection Automation** 连接 S_AXI
3. 引出外设端口：
   - `kb_row[3:0]`、`kb_col[3:0]` → Make External
   - `fp_sensor_tx`、`fp_sensor_rx` → Make External
   - `buzzer` → Make External

### 3. 约束文件
使用 `create_project.tcl` 中的完整 XDC（包含全部 PMOD 引脚）。

### 4. 生成 Bitstream → Export → Vitis → 导入 main.c → 运行

> **Vitis 版本差异**: 2022.2 使用 Platform/Application Project，2025.2 使用 Platform/Application Component。详见 Step 1 的 `README_manual.md` 第六部分。

---

## 预期结果
串口终端（115200 baud）显示：
```
========================================
 Step 4: All Peripherals Test
========================================

[LED] Running LED test...
  LED[0] ON
  LED[1] ON
  LED[2] ON
  LED[3] ON
[LED] DONE

[BUZZER] Short beep...
[BUZZER] OK tone...
[BUZZER] Fail tone...
[BUZZER] DONE

[KEYBOARD] Press 3 keys on keypad...
  Key pressed: code=1
  Key pressed: code=5
  Key pressed: code=10
[KEYBOARD] DONE

[FINGERPRINT] VfyPwd default password opcode=0x13 param=0x0000
  dbg=0x... rx_seen=... state=... tx_idx=.../... rx_cnt=... last_rx=0x...
  VfyPwd default password OK: ...
  Sensor responded: OK (password verified)
[FINGERPRINT] ReadSysPara opcode=0x0f param=0x0000
[FINGERPRINT] ValidTmplNum opcode=0x1d param=0x0000
[FINGERPRINT] DONE (link success)

All tests complete!
```

## 寄存器映射参考

| 偏移 | 名称 | 方向 | bit 分布 |
|------|------|------|---------|
| 0x00 | FP_CMD | W | [31]=start, [23:16]=opcode, [15:0]=param |
| 0x04 | FP_RESP | R | [31:24]=status, [15:0]=response |
| 0x08 | KB_DATA | R | [4]=valid, [3:0]=key_code |
| 0x0C | BUZZER | W | [2]=fail, [1]=ok, [0]=short |
| 0x10 | VGA_CHAR | W | [31]=we, [22:12]=addr, [7:0]=ascii |
| 0x14 | LED | W | [3:0]=led |
| 0x18 | FP_DBG | R | [27]=rx_seen, [26:24]=state, [23:19]=tx_idx, [18:13]=rx_cnt, [12:8]=pkt_len, [7:0]=last_rx |

`FP_DBG.state` 编码：0=idle，1=boot_wait，2=wake/guard，3=build，4=send/tx_gap，5=wait_resp，6=read/parse，7=done。

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 指纹传感器无响应 | JD PMOD 接线反了（TX↔RX 需要交叉）；传感器未供电 |
| 蜂鸣器无声 | JC PMOD 接线不对；蜂鸣器模块需 3.3V 供电 |
| C 编译报 BASEADDR 未定义 | 自定义 IP 未正确添加到 BD；重新 Export Hardware 并重建平台工程 |
| Generate Bitstream 报 `NSTD-1` | Clocking Wizard 差分时钟问题——使用更新后的 `create_bd.tcl` 或参见 Step 1 说明 |

> AS608 UART 说明：厂家资料/总结文档标称 57600 8N2，但当前合作方同款硬件纯 Verilog demo 已用 57600 8N1 跑通，因此 step4 默认按 8N1 集成。`fingerprint_ctrl.v` 首次命令前会自动执行 3s boot guard、`0x55` wake 和 1s guard，C 层无需额外发送 wake。若 `VfyPwd` 仍持续 timeout，可临时将 `fingerprint_ctrl.v` 中 TX/RX 的 `STOP_BITS` 改为 2 重新综合做 A/B 对照。
