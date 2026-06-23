# 完整系统集成

MicroBlaze + 单个自定义 AXI-Lite 外设（包装 5 个模块）+ C 应用代码。

## 目录结构
- `ip/fp_payment_periph/` — 自定义 AXI-Lite IP（寄存器文件 + 所有外设模块例化）
- `constraints/nexys4.xdc` — 完整引脚约束
- `sw/` — C 应用代码（主状态机、账户管理、支付、显示）

## 寄存器映射
| 偏移 | 名称 | 方向 | 描述 |
|------|------|------|------|
| 0x00 | FP_CMD | W | [31]=start, [23:16]=opcode, [15:0]=param |
| 0x04 | FP_RESP | R | [31:24]=status, [15:0]=response |
| 0x08 | KB_DATA | R | [4]=valid, [3:0]=key_code（读后清 valid）|
| 0x0C | BUZZER | W | [2]=fail, [1]=ok, [0]=short |
| 0x18 | FP_DBG | R | 指纹调试: rx_seen/state/tx_idx/rx_cnt/pkt_len/last_rx |
| 0x20 | VGA_CHAR | W | [31]=we, [22:12]=addr, [7:0]=ASCII |
| 0x24 | LED | W | [3:0]=LED |

> 详细实施将在 Phase 3 进行。
