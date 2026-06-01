# 引脚连接总览

## 开发板上连线（无需操作）

| 端口 | 信号 | FPGA 引脚 | 方向 | 电平 |
|------|------|-----------|------|------|
| 时钟 | `clk_100mhz` | E3 | ← | LVCMOS33 |
| 复位 | `rst_n` | C12 | ← | LVCMOS33 |
| LED0 | `led[0]` | H17 | → | LVCMOS33 |
| LED1 | `led[1]` | K15 | → | LVCMOS33 |
| LED2 | `led[2]` | J13 | → | LVCMOS33 |
| LED3 | `led[3]` | N14 | → | LVCMOS33 |
| 调试 TX | `debug_tx` | D4 | → 板载 FT2232 | LVCMOS33 |
| 调试 RX | `debug_rx` | C4 | ← 板载 FT2232 | LVCMOS33 |
| VGA_R[0..3] | | A3, B4, C5, A4 | → | LVCMOS33 |
| VGA_G[0..3] | | C6, A5, B6, A6 | → | LVCMOS33 |
| VGA_B[0..3] | | B7, C7, A7, C8 | → | LVCMOS33 |
| VGA_HSYNC | `vga_hsync` | D8 | → | LVCMOS33 |
| VGA_VSYNC | `vga_vsync` | A9 | → | LVCMOS33 |
| Flash CS | `flash_cs_n` | L13 | → | LVCMOS33 |
| Flash CLK | `flash_clk` | L16 | → | LVCMOS33 |
| Flash MOSI | `flash_mosi` | K17 | → | LVCMOS33 |
| Flash MISO | `flash_miso` | K18 | ← | LVCMOS33 |

---

## PMOD JB — 4×4 矩阵键盘

| PMOD 引脚 | 信号 | FPGA 引脚 | 键盘端 |
|-----------|------|-----------|--------|
| JB1 | `kb_row[0]` | G14 | 键盘行 1 |
| JB2 | `kb_row[1]` | P15 | 键盘行 2 |
| JB3 | `kb_row[2]` | V11 | 键盘行 3 |
| JB4 | `kb_row[3]` | V15 | 键盘行 4 |
| JB7 | `kb_col[0]` | K16 | 键盘列 1 |
| JB8 | `kb_col[1]` | R16 | 键盘列 2 |
| JB9 | `kb_col[2]` | T9 | 键盘列 3 |
| JB10 | `kb_col[3]` | U11 | 键盘列 4 |

---

## PMOD JD — AS608 指纹传感器

| PMOD 引脚 | 信号 | FPGA 引脚 | 传感器线（常见颜色） |
|-----------|------|-----------|----------------------|
| JD3 | `fp_sensor_tx` | G1 | RXD（绿/蓝）— FPGA → 传感器 |
| JD4 | `fp_sensor_rx` | G3 | TXD（黄/白）— 传感器 → FPGA |
| JD5 | GND | — | GND（黑） |
| JD6 | VCC (3.3V) | — | VCC（红） |

> 传感器 TOUCH / WAKE 线悬空不接。

---

## PMOD JC — 蜂鸣器（3 线有源模块）

| PMOD 引脚 | 信号 | FPGA 引脚 | 蜂鸣器线 |
|-----------|------|-----------|----------|
| JC4 | `buzzer` | Y1 | I/O |
| JC5 | GND | — | GND |
| JC6 | VCC (3.3V) | — | VCC |

---

## 完整接线图

```
                   Nexys4 DDR 开发板
    ┌──────────────────────────────────────────┐
    │                                          │
    │  VGA ──── VGA 显示器                      │
    │  PROG ─── MicroUSB → 电脑（供电 + 串口）    │
    │                                          │
    │  PMOD JB ──────── 4×4 键盘               │
    │    JB1..JB4  →  键盘行 1..4              │
    │    JB7..JB10 ←  键盘列 1..4              │
    │                                          │
    │  PMOD JD ──────── AS608 指纹传感器        │
    │    JD3  →  RXD                           │
    │    JD4  ←  TXD                           │
    │    JD5  ─  GND                           │
    │    JD6  ─  VCC (3.3V)                    │
    │                                          │
    │  PMOD JC ──────── 蜂鸣器                  │
    │    JC4  →  I/O                           │
    │    JC5  ─  GND                           │
    │    JC6  ─  VCC (3.3V)                    │
    │                                          │
    │  板载：LED0..3 / 按键 / Flash / 时钟      │
    └──────────────────────────────────────────┘
```
