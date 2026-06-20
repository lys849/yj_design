# AS608 指纹识别 Demo — Nexys4 DDR（纯 Verilog）

基于 **Digilent Nexys4 DDR** 和 **AS608 光学指纹模块** 的指纹录入与识别系统。

**纯 Verilog 实现**，无需 MicroBlaze / Vitis / SDK，一个 `.v` 工程直接综合生成 bitstream，串口终端查看结果。

---

## 功能

- **指纹录入**：BTNC 按键触发 → 采集两次手指图像 → 合并模板 → 存入 AS608 指纹库
- **指纹识别**：BTNU 按键触发 → 采集手指图像 → 搜索指纹库 → 显示匹配 ID 和得分
- 结果通过**串口终端**（USB-UART, 115200 bps）打印
- 4 个 **LED** 指示状态

---

## 硬件接线

| PMOD JD | FPGA 引脚 | 方向 | AS608 模块 | 线色建议 |
|---------|----------|------|-----------|---------|
| JD3 | **G1** | → | RXD | 黄 / 白 |
| JD4 | **G3** | ← | TXD | 绿 / 蓝 |
| JD5 | GND | — | GND | 黑 |
| JD6 | **3.3V** | — | VCC | 红 |

> ⚠️ AS608 供电必须是 **3.3V**！Nexys4 DDR 的 PMOD 口直出 3.3V，直接连接即可。

```
PMOD JD (开发板右上角 2×6 排针):
  JD1 □  □  □  □  □  □ JD6  ← VCC (3.3V) → 红线 → AS608 VCC
  JD7 □  □  □  □  □  □ JD12
       │  │  │  │
       │  │  │  └─ G3 → 绿线 → AS608 TXD
       │  │  └──── G1 → 黄线 → AS608 RXD
       │  │         GND → 黑线 → AS608 GND
```

---

## 项目结构

```
fingerprint/
├── README.md
├── src/
│   ├── top.v              ← 顶层模块（实例化所有子模块）
│   ├── uart_tx.v          ← UART 发送器（参数化波特率）
│   ├── uart_rx.v          ← UART 接收器（参数化波特率）
│   └── as608_ctrl.v       ← AS608 控制器 + 演示状态机
└── constraints/
    └── nexys4ddr_fp.xdc   ← 引脚约束
```

---

## 快速开始（Vivado 2022.2）

### 第一步：创建工程

1. 打开 **Vivado 2022.2**
2. **Create Project** → Next
3. Project name: `fingerprint_demo`，位置自选
4. Project Type: **RTL Project**，勾选 "Do not specify sources at this time" → Next
5. 在 "Default Part" 中搜索 **xc7a100tcsg324-1**（或选 Boards → Nexys4 DDR） → Next → Finish

### 第二步：添加源文件

1. 在 **Sources** 面板，右键 `Design Sources` → **Add Sources** → Add or create design sources → **Add Files**
2. 浏览到本项目 `src/` 目录，添加全部 4 个 `.v` 文件：
   - `top.v`
   - `uart_tx.v`
   - `uart_rx.v`
   - `as608_ctrl.v`
3. 勾选 "Copy sources into project" → Finish

### 第三步：添加约束文件

1. 右键 `Constraints` → **Add Sources** → Add or create constraints
2. 添加 `constraints/nexys4ddr_fp.xdc`
3. 勾选 "Copy constraints files into project" → Finish

### 第四步：生成 Bitstream

1. 在 Sources 面板确认 `top` 是顶层模块（图标应不同，如不是：右键 `top.v` → **Set as Top**）
2. 点击左侧 **Generate Bitstream**（或 Flow Navigator → Program and Debug → Generate Bitstream）
3. 弹出的对话框一律点 **OK** / **Yes**
4. 等待综合 + 布局布线完成（约 5–15 分钟）

### 第五步：下载运行

1. 用 MicroUSB 线连接 Nexys4 DDR 的 **PROG** 口到电脑
2. 在 Vivado 中点击 **Open Hardware Manager** → **Open Target** → **Auto Connect**
3. **Program Device** → 选择生成的 `.bit` 文件 → **Program**
4. 打开串口终端（Putty / Tera Term / Vitis Serial Terminal）：
   - **端口**：Nexys4 DDR 对应的 COM 口（设备管理器中查看，一般是 "USB Serial Port"）
   - **波特率**：**115200**
   - **数据位**：8 / 停止位：1 / 校验：None / 流控：None
5. 按下开发板上的 **CPU_RESET** 按钮，终端会显示初始化信息和菜单提示

### 预期终端输出

```
========================================
 AS608 Fingerprint Demo (Nexys4 DDR)
========================================

--- Sensor Init ---
  Sensor OK. Lib size=012C
  Stored: 0000

Press BTNC=Enroll, BTNU=Identify
```

---

## 使用说明

| 操作 | 按键 | 说明 |
|------|------|------|
| **录入指纹** | BTNC（中央按钮） | 按照终端提示放手指 → 移开 → 再放 |
| **识别指纹** | BTNU（上按钮） | 放手指，终端显示匹配 ID 和得分 |
| **复位** | CPU_RESET（左上角红色按钮） | 重新初始化传感器 |

### 录入流程

1. 按 **BTNC**，终端显示 `[Enroll] Place finger on sensor...`
2. 将手指平放在 AS608 传感器窗口上
3. 看到 `Image captured.` 后，终端提示 `Remove & place finger again...`
4. 移开手指，**再次放上同一手指**
5. 看到 `Enroll OK! ID=0000` 表示录入成功
6. ID 从 0000 开始自动递增

### 识别流程

1. 按 **BTNU**，终端显示 `[Identify] Place finger on sensor...`
2. 将手指放在传感器上
3. 匹配成功：`Match! ID=0000 Score=0045`
4. 未匹配：`No match found.`

### LED 状态

| LED | 引脚 | 含义 |
|-----|------|------|
| LED0 (H17) | 常亮 | 系统就绪 |
| LED1 (K15) | 亮 | 录入模式中 |
| LED2 (J13) | 亮 | 识别模式中 |
| LED3 (N14) | 亮 | 错误（检查接线） |

---

## 模块说明

### uart_tx.v / uart_rx.v

参数化的 UART 收发器：
- `CLK_FREQ`：系统时钟频率（默认 100MHz）
- `BAUD_RATE`：波特率

接口：
- **uart_tx**：`send`（脉冲触发）→ `busy`（发送中）→ `done`（完成）
- **uart_rx**：`rx`（串行输入）→ `valid`（1 周期脉冲）+ `data[7:0]`（接收字节）

### as608_ctrl.v

核心控制器，以状态机实现全部逻辑：
1. **初始化阶段**：发送 `ReadSysPara` / `ValidTmplNum` 指令验证传感器
2. **空闲阶段**：等待按键
3. **录入阶段**：GetImage → GenChar1 → GetImage → GenChar2 → RegModel → Store（自动分配 ID）
4. **识别阶段**：GetImage → GenChar1 → Search（返回 ID 和得分）
5. **消息输出**：内建消息 ROM，逐字符发送到调试串口

状态机含超时保护（2 秒响应超时）和手指轮询（无手指时每 800ms 重试 GetImage）。

---

## 故障排除

### 终端无输出

- 检查 COM 口和波特率（**115200**，不是 57600）
- 确认 MicroUSB 插在 **PROG** 口（不是 USB HOST 口）
- 按下 **CPU_RESET** 按钮重试
- 关闭其他占用同一 COM 口的程序

### 传感器初始化失败 (LED3 亮)

- 检查 4 根杜邦线连接：JD3→RXD, JD4→TXD, JD5→GND, JD6→VCC
- AS608 上电后应有红灯亮起
- 用万用表确认 JD6 电压是 3.3V
- TXD/RXD 是否接反（交叉连接是对的：FPGA TX→模块 RX, FPGA RX←模块 TX）

### 录入/识别一直失败

- 手指放平，覆盖整个传感器窗口（AS608 光学窗口约 14×18mm）
- 手指不要太干或太湿
- 录入时两次必须是**同一个手指**
- 如果持续报 "0x06"（图像太乱），用软布擦拭传感器窗口

### 常见错误码

| 错误码 | 含义 |
|--------|------|
| 0x00 | 成功 |
| 0x02 | 无手指 |
| 0x03 | 图像采集失败 |
| 0x06 | 图像太乱无法生成特征 |
| 0x07 | 特征点太少 |
| 0x08 | 指纹不匹配（RegModel 阶段） |
| 0x09 | 指纹库中未找到 |
| 0x0A | 特征合并失败（不是同一手指） |
| 0x12 | 通信超时（检查接线） |

---

## 扩展建议

- 把 AS608 的 `touch_out` 引脚（如果有）接到 FPGA 作为中断，替代轮询
- 加入 4×4 矩阵键盘实现密码+指纹双重认证
- 用板载 VGA 接口显示 UI 界面
- 蜂鸣器（A11 引脚）播放提示音

---

## 参考资料

- [Nexys4 DDR Reference Manual](https://digilent.com/reference/programmable-logic/nexys-4-ddr/reference-manual)
- [AS608 通讯协议](https://doc.grablo.co/en/docs/user-manuals/i-o-device/as608-fpm10a-fingerprint-sensor/)
- [Nexys4 DDR Master XDC](https://github.com/Digilent/Nexys4DDR)
