# 键盘模块板级测试

## 测试目标
验证 4×4 矩阵键盘扫描、消抖在真实硬件上工作正常。按键后 LED 显示对应键码。

## 硬件连接

| 接口 | 连接 |
|------|------|
| MicroUSB | PROG 口 → PC（供电 + 下载） |
| PMOD JB | 4×4 矩阵键盘（8 线：4 行 + 4 列） |

PMOD JB 接线顺序：

```
JB1 (D14) → 键盘行 0     JB7 (E16) → 键盘列 0
JB2 (F16) → 键盘行 1     JB8 (F13) → 键盘列 1
JB3 (G16) → 键盘行 2     JB9 (G13) → 键盘列 2
JB4 (H14) → 键盘行 3     JB10(H16) → 键盘列 3
```

> 不同品牌键盘的行列引脚顺序可能不同，如果按键结果不对，尝试交换行/列接线。

## 源文件清单

| 文件 | 路径 |
|------|------|
| 测试顶层 | `modules/keyboard/board_test/kb_test_top.v` |
| 键盘扫描 | `modules/keyboard/rtl/keyboard_scan.v` |
| 引脚约束 | `modules/keyboard/board_test/kb_test.xdc` |

## Vivado 操作步骤

### 1. 创建工程
1. 打开 Vivado 2022.2
2. **Create Project** → Project Name: `kb_board_test`
3. Project Type: **RTL Project**
4. **Add Sources** → 选择上述 2 个 `.v` 文件
5. **Add Constraints** → 选择 `kb_test.xdc`
6. **Default Part** → `xc7a100tcsg324-1`
7. **Finish**

### 2. 设置顶层模块
Sources 面板 → 右键 `kb_test_top` → **Set as Top**

### 3. 生成 Bitstream
Flow Navigator → **Generate Bitstream** → 等待 3-5 分钟

### 4. 下载到开发板
**Open Hardware Manager** → **Auto Connect** → **Program Device**

## 验证方法

按下矩阵键盘上的任意按键，观察开发板上 LED[3:0] 的亮灭组合。

## 预期结果

LED 以二进制方式显示按键的原始扫描码（key_code = 行×4 + 列）：

| 按键面 | key_code | LED[3:0] |
|--------|----------|----------|
| 1 | 0 | 0000 |
| 2 | 1 | 0001 |
| 3 | 2 | 0010 |
| A | 3 | 0011 |
| 4 | 4 | 0100 |
| 5 | 5 | 0101 |
| 6 | 6 | 0110 |
| B | 7 | 0111 |
| 7 | 8 | 1000 |
| 8 | 9 | 1001 |
| 9 | 10 | 1010 |
| C | 11 | 1011 |
| * | 12 | 1100 |
| 0 | 13 | 1101 |
| # | 14 | 1110 |
| D | 15 | 1111 |

> 上表基于标准键盘接线。实际映射取决于你的键盘行列引脚顺序，**到手后需逐键确认**。

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 按键完全无反应 | 键盘未接或接线松动；PMOD JB 方向插反 |
| 按一个键 LED 闪烁不定 | 接触不良导致消抖失败；检查杜邦线连接 |
| 按键对应关系全乱 | 行列接线顺序不对——交换行组和列组的杜邦线 |
| 只有部分键有效 | 某根行线或列线未接通——逐根检查 |
