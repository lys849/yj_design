# VGA 模块板级测试

## 测试目标
验证 VGA 时序控制器和文字渲染器在真实硬件上工作正常。屏幕显示测试文字。

## 硬件连接

| 接口 | 连接 |
|------|------|
| MicroUSB | PROG 口 → PC（供电 + 下载） |
| VGA 接口 | VGA 线 → 支持 VGA 输入的显示器 |

> Nexys4 DDR 的 VGA 输出为 12-bit 色深（R/G/B 各 4 位），标准 VGA 显示器均兼容。

## 源文件清单

| 文件 | 路径 |
|------|------|
| 测试顶层 | `modules/vga/board_test/vga_test_top.v` |
| VGA 时序控制 | `modules/vga/rtl/vga_ctrl.v` |
| 文字渲染器 | `modules/vga/rtl/vga_text.v` |
| 引脚约束 | `modules/vga/board_test/vga_test.xdc` |

## Vivado 操作步骤

### 1. 创建工程
1. 打开 Vivado 2022.2
2. **Create Project** → Project Name: `vga_board_test`
3. Project Type: **RTL Project**
4. **Add Sources** → 选择上述 3 个 `.v` 文件
5. **Add Constraints** → 选择 `vga_test.xdc`
6. **Default Part** → `xc7a100tcsg324-1`
7. **Finish**

### 2. 设置顶层模块
Sources 面板 → 右键 `vga_test_top` → **Set as Top**

### 3. 生成 Bitstream
Flow Navigator → **Generate Bitstream** → 等待 3-5 分钟

### 4. 下载到开发板
**Open Hardware Manager** → **Auto Connect** → **Program Device**

## 验证方法

下载完成后直接观察 VGA 显示器。

## 预期结果
- 屏幕背景为**深蓝色**
- 左上角第一行显示白色文字 **"HELLO VGA TEST"**
- LED[3] 亮起（表示 MMCM 时钟锁定成功）
- 画面稳定不闪烁、无撕裂

## 技术说明
- 本测试使用 `MMCME2_BASE` 原语将 100MHz 时钟转换为 25MHz VGA 像素时钟
- 字符缓冲区（80×30 = 2400 字节）使用 BRAM 存储，通过 `initial` 块初始化为空格
- 字体为内嵌的 8×16 点阵 ROM，目前覆盖数字 0-9、大写字母 A-B、常用符号

## 故障排查

| 现象 | 可能原因 |
|------|----------|
| 显示器无信号 | VGA 线未接好；显示器未切换到 VGA 输入源 |
| 画面闪烁或滚动 | MMCM 未锁定——检查 LED[3] 是否亮；时钟约束可能有问题 |
| 有画面但无文字 | font_rom 数据不完整——当前仅覆盖部分 ASCII 字符 |
| 颜色不对 | XDC 中 VGA R/G/B 引脚顺序与板子不匹配 |
| LED[3] 不亮 | MMCM 配置参数有误或时钟输入未正确连接 |
