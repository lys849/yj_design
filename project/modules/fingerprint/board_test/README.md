# 指纹传感器模块板级测试

## 测试目标
验证 FPGA 能通过 UART 与 AS608 指纹传感器通信。上电后自动发送口令验证命令（VfyPwd），LED 显示传感器是否应答。

## 硬件连接

| 接口 | 连接 |
|------|------|
| MicroUSB | PROG 口 → PC（供电 + 下载） |
| PMOD JD | AS608 指纹传感器（4 线） |

PMOD JD 接线：

```
JD3 (G1) → 传感器 RXD（绿/蓝线）    FPGA 发送 → 传感器接收
JD4 (G3) ← 传感器 TXD（黄/白线）    传感器发送 → FPGA 接收
JD5      → GND（黑线）
JD6      → VCC 3.3V（红线）
```

> **注意**：TX/RX 是交叉连接——FPGA 的 TX 接传感器的 RX，反之亦然。AS608 模块的 TOUCH/WAKE 线悬空不接。

## 源文件清单

| 文件 | 路径 |
|------|------|
| 测试顶层 | `modules/fingerprint/board_test/fp_test_top.v` |
| 指纹控制器 | `modules/fingerprint/rtl/fingerprint_ctrl.v` |
| UART 发送器 | `modules/uart/rtl/uart_tx.v` |
| UART 接收器 | `modules/uart/rtl/uart_rx.v` |
| 引脚约束 | `modules/fingerprint/board_test/fp_test.xdc` |

> 指纹控制器内部例化了 uart_tx 和 uart_rx，因此需要同时添加 UART 模块的源文件。

## Vivado 操作步骤

### 1. 创建工程
1. 打开 Vivado 2022.2
2. **Create Project** → Project Name: `fp_board_test`
3. Project Type: **RTL Project**
4. **Add Sources** → 选择上述 4 个 `.v` 文件
5. **Add Constraints** → 选择 `fp_test.xdc`
6. **Default Part** → `xc7a100tcsg324-1`
7. **Finish**

### 2. 设置顶层模块
Sources 面板 → 右键 `fp_test_top` → **Set as Top**

### 3. 生成 Bitstream
Flow Navigator → **Generate Bitstream** → 等待 3-5 分钟

### 4. 下载到开发板
**Open Hardware Manager** → **Auto Connect** → **Program Device**

## 验证方法

下载完成后，等待约 **3 秒**（AS608 上电初始化），程序自动发送 VfyPwd 命令。如果失败会自动重试（最多 3 次，每次间隔 500ms）。

## 预期结果

| LED | 状态 | 含义 |
|-----|------|------|
| LED[0] | 亮 | 传感器有应答（收到了响应数据包） |
| LED[1] | 亮 | 口令验证成功（默认口令 0x00000000 通过） |
| LED[3] | 亮 | 超时或错误（传感器未应答） |

**正常情况**：约 **3-4 秒**后 LED[0] 和 LED[1] 同时亮起，LED[3] 不亮。
**全部失败**：约 **27 秒**后（3 次重试 × 8 秒超时）LED[0] 和 LED[3] 亮起。

## AS608 通信参数
- 波特率：57600 bps
- 数据格式：工程默认 8 数据位，1 停止位，无校验（8N1）
- 说明：厂家资料/总结文档标称 57600 8N2，但当前 Nexys4 DDR + AS608 实测可用 8N1；若仍超时，可将 `fingerprint_ctrl.v` 中 TX/RX 的 `STOP_BITS` 改为 2 后重新综合做对照
- 默认设备地址：0xFFFFFFFF
- 默认口令：0x00000000

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 仅 LED[3] 亮（超时） | 传感器未接通电源（检查 VCC/GND）；TX/RX 接反了 |
| LED[0] 亮但 LED[1] 不亮 | 传感器口令已被修改（非默认 0x00000000）|
| 全部 LED 不亮 | Bitstream 未下载成功；或上电延迟不够（尝试按 CPU_RESET）|
| 传感器上电后蓝色灯不亮 | 传感器供电不足——检查 3.3V 是否稳定；某些 AS608 模块需要 5V 供电 |
