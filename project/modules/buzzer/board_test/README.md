# 蜂鸣器模块板级测试

## 测试目标
验证 PWM 蜂鸣器控制器在真实硬件上工作正常。通过开发板上的 3 个按钮触发 3 种不同音效。

## 硬件连接

| 接口 | 连接 |
|------|------|
| MicroUSB | PROG 口 → PC（供电 + 下载） |
| PMOD JC | 有源蜂鸣器模块（3 线） |

PMOD JC 接线：

```
JC4 (G6) → 蜂鸣器信号线（I/O）
JC5      → GND
JC6      → VCC (3.3V)
```

> 建议使用带驱动三极管的有源蜂鸣器模块（标称 3.3V），FPGA GPIO 直驱电流可能不足以驱动无驱动电路的蜂鸣器。

## 源文件清单

| 文件 | 路径 |
|------|------|
| 测试顶层 | `modules/buzzer/board_test/buzzer_test_top.v` |
| 蜂鸣器控制器 | `modules/buzzer/rtl/buzzer_ctrl.v` |
| 引脚约束 | `modules/buzzer/board_test/buzzer_test.xdc` |

## Vivado 操作步骤

### 1. 创建工程
1. 打开 Vivado 2022.2
2. **Create Project** → Project Name: `buzzer_board_test`
3. Project Type: **RTL Project**
4. **Add Sources** → 选择上述 2 个 `.v` 文件
5. **Add Constraints** → 选择 `buzzer_test.xdc`
6. **Default Part** → `xc7a100tcsg324-1`
7. **Finish**

### 2. 设置顶层模块
Sources 面板 → 右键 `buzzer_test_top` → **Set as Top**

### 3. 生成 Bitstream
Flow Navigator → **Generate Bitstream** → 等待 3-5 分钟

### 4. 下载到开发板
**Open Hardware Manager** → **Auto Connect** → **Program Device**

## 验证方法

下载完成后，按开发板上的按钮触发音效：

| 按钮 | 位置 | 触发音效 |
|------|------|---------|
| **BTNC** | 中央按钮 | 短蜂鸣（50ms） |
| **BTNU** | 上方按钮 | 成功长音（200ms） |
| **BTND** | 下方按钮 | 失败双响（100ms 响 + 100ms 停 + 100ms 响） |

按下按钮的同时，对应的 LED 也会亮起指示当前按下的按钮。

## 预期结果
- 按 **BTNC**：听到一声短促的"嘀"
- 按 **BTNU**：听到一声较长的"嘀——"
- 按 **BTND**：听到两声短促的"嘀—嘀"
- 每种音效播放期间，再按其他按钮**不会中断**当前音效（需等播放完成）
- 音调约为 **1kHz**（中等频率蜂鸣声）

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 完全无声 | 蜂鸣器未接通电源（检查 VCC/GND）；JC4 信号线未接；蜂鸣器模块坏了 |
| 按一次响不停 | 不应出现——buzzer_ctrl 使用边沿检测，每次按下只触发一次。如果出现，检查按钮是否持续导通 |
| 声音很小 | FPGA GPIO 驱动能力不足——需使用带三极管的蜂鸣器模块 |
| LED 亮但无声 | 信号线接对了但蜂鸣器供电不够——检查 VCC 是否接到 JC6（3.3V）|
| 按钮没反应 | XDC 中按钮引脚映射不对——BTNC=N17, BTNU=M18, BTND=P18 |
