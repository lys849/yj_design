#!/usr/bin/env python3
# Generate 开题立项说明书 (.docx) and 开题答辩PPT (.pptx)

from docx import Document
from docx.shared import Inches, Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from pptx import Presentation
from pptx.util import Inches as PptInches, Pt as PptPt
from pptx.dml.color import RGBColor as PptRGBColor
from pptx.enum.text import PP_ALIGN
import os

# Short aliases
Pi = PptInches
Ppt = PptPt

output_dir = "/Users/shen/yunshen/yj_design"

# ============================================
# Part 1: 开题立项说明书 (.docx)
# ============================================

doc = Document()

# Page setup
for section in doc.sections:
    section.top_margin = Cm(2.54)
    section.bottom_margin = Cm(2.54)
    section.left_margin = Cm(3.17)
    section.right_margin = Cm(3.17)

style = doc.styles['Normal']
font = style.font
font.name = '宋体'
font.size = Pt(12)

# ---- Cover page ----
for _ in range(6):
    doc.add_paragraph()

title = doc.add_paragraph()
title.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title.add_run('华中科技大学电信学院')
run.font.size = Pt(22)
run.font.bold = True

title2 = doc.add_paragraph()
title2.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title2.add_run('硬件技术课程设计')
run.font.size = Pt(22)
run.font.bold = True

doc.add_paragraph()

title3 = doc.add_paragraph()
title3.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = title3.add_run('开题立项说明书')
run.font.size = Pt(26)
run.font.bold = True

doc.add_paragraph()
doc.add_paragraph()

# Project info table
info_items = [
    ('项目名称', '指纹识别的支付系统'),
    ('学生姓名', '___________'),
    ('学    号', '___________'),
    ('班    级', '___________'),
    ('指导教师', '___________'),
    ('日    期', '2026年5月'),
]

table = doc.add_table(rows=len(info_items), cols=2)
table.alignment = WD_TABLE_ALIGNMENT.CENTER
for i, (key, val) in enumerate(info_items):
    cell0 = table.cell(i, 0)
    cell1 = table.cell(i, 1)
    cell0.text = key
    cell1.text = val
    for cell in [cell0, cell1]:
        for p in cell.paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER

doc.add_page_break()

# ---- Page 2: 摘要 & 关键词 ----
doc.add_paragraph()
h = doc.add_paragraph()
h.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = h.add_run('摘要')
run.font.size = Pt(16)
run.font.bold = True

abstract = (
    '本项目设计并实现一套基于FPGA的指纹识别支付系统，采用Xilinx FPGA开发板作为主控单元，'
    '通过光传感指纹识别模块实现指纹的采集、特征提取与比对认证。系统包含账户管理和支付两大子系统：'
    '账户管理支持开户、销户、充值、余额查询等操作；支付系统支持消费金额输入、指纹认证及自动扣款。'
    '系统通过VGA显示屏呈现用户交互界面，使用矩阵键盘进行功能操作，并提供蜂鸣器音频反馈。'
    '本系统将数字电路设计、嵌入式系统开发与生物识别技术相结合，具有较强的工程实践价值。'
)
p = doc.add_paragraph()
run = p.add_run(abstract)
run.font.size = Pt(12)

doc.add_paragraph()
kw = doc.add_paragraph()
run = kw.add_run('关键词：FPGA；指纹识别；支付系统；VGA显示；Verilog HDL')
run.font.bold = True
run.font.size = Pt(12)

# ---- Page 3+: Main content ----
doc.add_page_break()

sections = [
    ('一、项目概述', 
     '指纹识别技术凭借其唯一性、稳定性和便捷性，已成为生物识别领域应用最广泛的技术之一。'
     '本项目旨在设计一套基于FPGA的指纹识别支付系统，将指纹认证技术应用于日常消费支付场景，'
     '替代传统的密码、IC卡等身份验证方式，提供更安全、便捷的支付体验。\n\n'
     '系统以Xilinx FPGA开发板为核心控制单元，集成光传感指纹识别模块、VGA显示模块、'
     '矩阵键盘模块和蜂鸣器音频模块。采用Verilog HDL设计硬件接口控制器，'
     '使用C语言在MicroBlaze软核处理器上实现业务逻辑。系统由上电自检、主菜单导航、'
     '账户管理和支付交易四大流程组成。'),

    ('二、项目功能指标',
     '基本功能指标：\n'
     '(1) 指纹管理：支持指纹录入（两次采集合成模板）、指纹删除、指纹库清空；\n'
     '(2) 指纹比对：支持1:1精确比对和1:N数据库搜索，匹配阈值可调；\n'
     '(3) VGA显示：640×480分辨率，显示菜单界面、账户信息、交易状态；\n'
     '(4) 矩阵键盘：16键矩阵键盘，支持数字输入和功能选择；\n'
     '(5) 账户管理：账户创建（绑定指纹）、账户删除、余额充值、余额查询；\n'
     '(6) 支付功能：金额输入、指纹认证、余额校验、自动扣款；\n'
     '(7) 音频反馈：按键提示音、操作成功音、操作失败音；\n'
     '(8) 数据持久化：账户数据和指纹模板存储于外部SPI Flash，掉电不丢失。\n\n'
     '拓展功能指标（拟实现）：\n'
     '(1) SD卡大容量指纹库存储，支持更多用户；\n'
     '(2) 交易记录查询功能；\n'
     '(3) 串口连接上位机进行账户管理。'),

    ('三、系统框图',
     '系统总体架构如下所示，由FPGA主控芯片及其外围模块组成：\n\n'
     '┌─────────────────────────────────────────┐\n'
     '│              Xilinx FPGA                 │\n'
     '│  ┌──────────┐  ┌──────────┐             │\n'
     '│  │UART控制器│  │VGA控制器 │             │\n'
     '│  │(指纹模块)│  │(640×480) │             │\n'
     '│  └────┬─────┘  └────┬─────┘             │\n'
     '│       │              │                   │\n'
     '│  ┌────┴──────────────┴──────────────┐   │\n'
     '│  │      MicroBlaze 软核处理器        │   │\n'
     '│  │   (C语言: 账户管理 + 支付逻辑)    │   │\n'
     '│  └────┬──────────────┬──────────────┘   │\n'
     '│       │              │                   │\n'
     '│  ┌────┴─────┐  ┌────┴─────┐             │\n'
     '│  │键盘扫描  │  │PWM音频   │             │\n'
     '│  │(4×4矩阵)│  │(蜂鸣器)  │             │\n'
     '│  └──────────┘  └──────────┘             │\n'
     '│  ┌──────────┐  ┌──────────────────────┐ │\n'
     '│  │SPI Flash │  │  AXI 总线互连        │ │\n'
     '│  │(数据存储)│  │  (寄存器映射)        │ │\n'
     '│  └──────────┘  └──────────────────────┘ │\n'
     '└─────────────────────────────────────────┘\n\n'
     '外围器件：\n'
     '- 光传感指纹模块 (AS608)，通过UART接口与FPGA通信\n'
     '- VGA显示器，通过VGA接口输出25MHz像素时钟信号\n'
     '- 4×4矩阵键盘，通过GPIO扫描实现按键检测\n'
     '- 有源蜂鸣器，通过PWM方式驱动\n'
     '- SPI Flash (W25Qxx系列)，用于存储账户数据和指纹模板'),

    ('四、关键技术及实施方案',
     '4.1 指纹模块驱动技术\n'
     '指纹传感器（AS608兼容）通过UART串口（57600bps，8N1）与FPGA通信。'
     'FPGA端设计UART收发控制器（Verilog实现），MicroBlaze端设计指纹协议驱动（C语言实现）。'
     '协议采用命令-应答模式，支持GetImage、GenChar、RegModel、Store、Search等核心指令。'
     '指纹录入流程为：两次采集图像→分别生成特征文件→合并特征生成模板→存储至指纹库。'
     '指纹比对流程为：采集图像→生成特征→在指纹库中1:N搜索→返回匹配结果。\n\n'
     '4.2 VGA显示技术\n'
     'VGA控制器采用640×480@60Hz标准时序（25MHz像素时钟），'
     'H_Active=640, H_Front=16, H_Sync=96, H_Back=48, H_Total=800；'
     'V_Active=480, V_Front=10, V_Sync=2, V_Back=33, V_Total=525。'
     '字符渲染模块内置5×7点阵字库ROM，支持ASCII可见字符渲染，'
     '提供80列×30行的字符网格，通过字符缓冲区实现MicroBlaze对显示内容的实时更新。\n\n'
     '4.3 键盘扫描与消抖\n'
     '采用行列扫描法：FPGA依次输出低电平扫描各行，读取列输入状态。'
     '当检测到按键按下时，启动20ms硬件消抖计数器，确认稳定后给出按键有效信号。'
     '支持16键：数字0-9用于金额输入，A-F定义为确认、取消、上翻、下翻、菜单、删除等功能键。\n\n'
     '4.4 数据持久化存储\n'
     '采用SPI Flash（W25Qxx系列）存储账户数据和指纹模板。Flash地址空间划分：'
     '0x000000-0x00FFFF为指纹模板区（32个×512字节），0x010000-0x01FFFF为账户数据区（32个×64字节）。'
     'FPGA端设计SPI主控制器（模式0，5MHz速率），支持读、写、扇区擦除操作。'
     'MicroBlaze端封装存储层API，提供读写接口。\n\n'
     '4.5 MicroBlaze软核处理器\n'
     '使用Xilinx Vivado搭建MicroBlaze软核处理器系统，通过AXI4-Lite总线连接各外设控制器。'
     '外设寄存器映射到统一地址空间（0x40000000基地址），C程序通过寄存器读写控制外设。'
     '主程序采用轮询+状态机架构：键盘输入驱动状态转换，指纹操作和支付交易以同步阻塞方式完成。'),

    ('五、可行性论证',
     '本系统各模块均已完成详细设计和仿真验证，具体如下：\n\n'
     '(1) UART收发模块：已完成Verilog RTL设计和仿真验证，在57600bps波特率下测试了5组不同数据（0xA5、0x55、0x00、0xFF、0x3C），'
     'TX→RX回路测试全部通过，数据传输正确无误。\n\n'
     '(2) VGA控制器：已完成640×480@60Hz时序设计和仿真验证，HSYNC/VSYNC极性正确，'
     '帧率约59.5Hz符合标准，字符字体模块可正常渲染ASCII可见字符。\n\n'
     '(3) 键盘扫描器：已完成4×4矩阵扫描和20ms消抖逻辑的仿真验证，按键检测和编码输出功能正常。\n\n'
     '(4) 指纹控制器：已完成AS608协议命令组包和UART串行发送的仿真验证，支持GetImage、Search、Enroll等核心指令。\n\n'
     '(5) 蜂鸣器控制器：已完成PWM音频驱动设计，支持短促提示音(50ms)、成功长音(200ms)和失败双音三种模式。\n\n'
     '(6) SPI Flash控制器：已完成SPI模式0主控制器设计，支持读、写、扇区擦除操作，速率5MHz。\n\n'
     '(7) 顶层集成：已完成所有8个模块的顶层集成设计和联合仿真验证，各模块接口匹配，系统可正常启动和运行。\n\n'
     '(8) 软件层面：已完成MicroBlaze C程序框架设计，包括主控状态机、账户管理、支付逻辑、存储层和显示层的完整API。\n\n'
     '综上所述，各功能模块技术方案成熟、仿真验证通过，系统整体设计可行。'),

    ('六、项目实施计划',
     '第11-12周（立项与开题）：需求分析、技术方案论证、元件选型、撰写开题报告及答辩PPT。\n\n'
     '第13周（电路设计）：各模块电路原理图设计、关键信号仿真验证、元件采购与申请。\n\n'
     '第14周（单元实现与中期检查）：\n'
     '  - 完成指纹模块驱动调试（UART通信+协议实现）\n'
     '  - 完成VGA显示驱动与字符渲染\n'
     '  - 完成键盘扫描与消抖模块\n'
     '  - 完成蜂鸣器驱动\n'
     '  - 撰写中期进展报告\n\n'
     '第15-16周（系统联调）：\n'
     '  - 集成所有硬件模块\n'
     '  - 实现账户管理完整功能\n'
     '  - 实现支付交易完整流程\n'
     '  - 系统联调与功能测试\n\n'
     '第17周（验收）：功能验收测试、录制演示视频、提交项目文档。\n\n'
     '第18周（总结）：撰写课程设计说明书（10000字以上）、整理源码与工程文件、制作答辩PPT。'),

    ('七、主要器件清单',
     '1. Xilinx FPGA开发板 (如Nexys4 DDR / Basys3) ×1\n'
     '2. 光传感指纹识别模块 (AS608 / R308) ×1\n'
     '3. VGA显示器 ×1\n'
     '4. 4×4矩阵键盘模块 ×1\n'
     '5. 有源蜂鸣器模块 ×1\n'
     '6. SPI Flash芯片 (W25Q32 / W25Q64) ×1 (如开发板未集成)\n'
     '7. 杜邦线、面包板、排针等接插件 若干\n'
     '8. USB下载线 ×1\n'
     '9. 5V电源适配器 ×1'),

    ('八、参考资料',
     '[1] 田耘, 徐文波. Xilinx FPGA开发实用教程[M]. 清华大学出版社, 2012.\n'
     '[2] 谢自美. 电子线路综合设计[M]. 华中科技大学出版社, 2006.\n'
     '[3] 阮秋琦. 数字图像处理[M]. 电子工业出版社, 2013.\n'
     '[4] 康华光. 电子技术基础: 数字部分(第五版)[M]. 高等教育出版社, 2006.\n'
     '[5] 孟宪元, 钱伟康. FPGA嵌入式系统设计[M]. 电子工业出版社, 2012.\n'
     '[6] AS608 Fingerprint Module Datasheet, Hangzhou Grow Technology.\n'
     '[7] Xilinx UG1046: MicroBlaze Processor Reference Guide, 2023.\n'
     '[8] Xilinx UG572: UltraScale Architecture Clocking Resources, 2023.'),
]

for title, content in sections:
    h = doc.add_paragraph()
    run = h.add_run(title)
    run.font.size = Pt(14)
    run.font.bold = True

    p = doc.add_paragraph()
    run = p.add_run(content)
    run.font.size = Pt(12)
    p_format = p.paragraph_format
    p_format.line_spacing = 1.5

    if title != '八、参考资料':
        doc.add_paragraph()

# Save document
doc_path = os.path.join(output_dir, '开题立项说明书_指纹支付的识别系统.docx')
doc.save(doc_path)
print(f"[OK] 开题立项说明书已生成: {doc_path}")

# ============================================
# Part 2: 开题答辩PPT (.pptx)
# ============================================

prs = Presentation()
prs.slide_width = PptInches(13.333)
prs.slide_height = PptInches(7.5)

def add_slide(title_text, content_lines, title_color=PptRGBColor(0x1A, 0x3C, 0x6E)):
    slide_layout = prs.slide_layouts[6]  # blank
    slide = prs.slides.add_slide(slide_layout)

    # Background
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = PptRGBColor(0xF5, 0xF5, 0xF5)

    # Title bar
    left = Pi(0)
    top = Pi(0)
    width = Pi(13.333)
    height = Pi(1.2)
    shape = slide.shapes.add_shape(1, left, top, width, height)  # 1 = rectangle
    shape.fill.solid()
    shape.fill.fore_color.rgb = title_color
    shape.line.fill.background()
    tf = shape.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = title_text
    p.font.size = Ppt(32)
    p.font.color.rgb = PptRGBColor(0xFF, 0xFF, 0xFF)
    p.font.bold = True
    p.alignment = PP_ALIGN.LEFT
    tf.margin_left = Pi(0.5)

    # Content
    left = Pi(0.5)
    top = Pi(1.5)
    width = Pi(12.333)
    height = Pi(5.5)
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.word_wrap = True

    for i, line in enumerate(content_lines):
        if i == 0:
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.text = line
        p.font.size = Ppt(20)
        p.font.color.rgb = PptRGBColor(0x33, 0x33, 0x33)
        p.space_after = Ppt(8)
        if line.startswith('■') or line.startswith('◆'):
            p.font.size = Ppt(24)
            p.font.color.rgb = title_color
            p.font.bold = True

    return slide

# Slide 1: Title
slide_layout = prs.slide_layouts[6]
slide = prs.slides.add_slide(slide_layout)
bg = slide.background
fill = bg.fill
fill.solid()
fill.fore_color.rgb = PptRGBColor(0x1A, 0x3C, 0x6E)

left = PptInches(0)
top = PptInches(0)
width = PptInches(13.333)
height = PptInches(7.5)
shape = slide.shapes.add_shape(1, left, top, width, height)
shape.fill.solid()
shape.fill.fore_color.rgb = PptRGBColor(0x1A, 0x3C, 0x6E)
shape.line.fill.background()

txBox = slide.shapes.add_textbox(PptInches(1), PptInches(1.5), PptInches(11), PptInches(4.5))
tf = txBox.text_frame
tf.word_wrap = True

p = tf.paragraphs[0]
p.text = '指纹识别的支付系统'
p.font.size = Ppt(48)
p.font.color.rgb = PptRGBColor(0xFF, 0xFF, 0xFF)
p.font.bold = True
p.alignment = PP_ALIGN.CENTER

p2 = tf.add_paragraph()
p2.text = '硬件技术课程设计 — 开题答辩'
p2.font.size = Ppt(28)
p2.font.color.rgb = PptRGBColor(0xCC, 0xDD, 0xFF)
p2.alignment = PP_ALIGN.CENTER

p3 = tf.add_paragraph()
p3.text = ''
p3.font.size = Ppt(16)

p4 = tf.add_paragraph()
p4.text = '华中科技大学 电信学院'
p4.font.size = Ppt(22)
p4.font.color.rgb = PptRGBColor(0xAA, 0xBB, 0xEE)
p4.alignment = PP_ALIGN.CENTER

p5 = tf.add_paragraph()
p5.text = '2026年5月'
p5.font.size = Ppt(18)
p5.font.color.rgb = PptRGBColor(0x99, 0xAA, 0xDD)
p5.alignment = PP_ALIGN.CENTER

# Slide 2: Project Background
add_slide('项目背景与需求', [
    '■ 背景',
    '   • 指纹识别技术凭借唯一性、稳定性在安防/支付领域广泛应用',
    '   • 传统密码/IC卡支付存在遗忘、丢失、被盗等安全隐患',
    '   • FPGA高性能低功耗特性适合嵌入式信号处理与实时控制',
    '',
    '■ 项目需求',
    '   • 光传感指纹模块实现指纹录入、比对、识别',
    '   • VGA显示屏呈现系统交互界面',
    '   • 矩阵键盘实现功能选择与数字输入',
    '   • 双子系统：账户管理（开户/销户/充值/查询）',
    '                 支付系统（消费输入→指纹认证→扣款）',
])

# Slide 3: System Architecture
add_slide('系统总体设计', [
    '◆ 核心方案：Xilinx FPGA + MicroBlaze软核处理器',
    '',
    '   ┌────────────────────────────────────┐',
    '   │          FPGA 内部架构              │',
    '   │  UART控制器 ←→ 指纹传感器           │',
    '   │  VGA控制器  ←→ VGA显示器 (640×480)  │',
    '   │  键盘扫描器 ←→ 4×4矩阵键盘          │',
    '   │  PWM控制器  ←→ 蜂鸣器               │',
    '   │  SPI控制器  ←→ Flash存储            │',
    '   │  MicroBlaze 软核 (AXI总线连接)      │',
    '   │    ├ 账户管理系统 (C)               │',
    '   │    └ 支付系统     (C)               │',
    '   └────────────────────────────────────┘',
    '',
    '◆ 开发语言：Verilog HDL (硬件接口) + C (应用逻辑)',
])

# Slide 4: Key Technologies
add_slide('关键技术方案', [
    '■ 指纹识别 (UART 57600bps → AS608协议)',
    '   • 指纹录入：两采图像 → 特征提取 → 模板合成 → 存储',
    '   • 指纹比对：采集 → 特征 → 1:N搜索 → 阈值判断',
    '',
    '■ VGA显示 (640×480@60Hz, 25MHz像素时钟)',
    '   • 标准VGA时序 + 5×7点阵字库ROM + 80×30字符缓冲区',
    '',
    '■ 键盘输入 (4×4矩阵扫描 + 20ms硬件消抖)',
    '   • 16键支持：数字0-9 + 确认/取消/上下/菜单/删除',
    '',
    '■ 数据存储 (SPI Flash W25Qxx, 模式0, 5MHz)',
    '   • 指纹模板区(16KB) + 账户数据区(2KB) → 支持32用户',
    '',
    '■ 音频反馈 (PWM驱动蜂鸣器)',
    '   • 短音50ms(按键) / 长音200ms(成功) / 双音(失败)',
])

# Slide 5: Feasibility Verification
add_slide('可行性验证 — 仿真测试结果', [
    '◆ 全部8个模块已通过Verilog仿真验证 (Icarus Verilog)',
    '',
    '   ┌──────────────┬──────────┬──────────────────┐',
    '   │ 模块          │ 测试项    │ 验证结果          │',
    '   ├──────────────┼──────────┼──────────────────┤',
    '   │ UART TX/RX    │ 回路测试  │ 5组数据全部正确   │',
    '   │ VGA控制器     │ 时序验证  │ 640×480@59.5Hz   │',
    '   │ 键盘扫描器    │ 消抖测试  │ 按键检测正常      │',
    '   │ 指纹控制器    │ 协议测试  │ 命令组包/发送正常  │',
    '   │ 蜂鸣器控制器  │ PWM生成   │ 3种模式独立正常   │',
    '   │ SPI Flash     │ 读写逻辑  │ 模式0时序正确     │',
    '   │ VGA字体渲染   │ 字形输出  │ ASCII字库完整     │',
    '   │ 顶层集成      │ 联合仿真  │ 8模块协同正常     │',
    '   └──────────────┴──────────┴──────────────────┘',
    '',
    '   C代码框架已完成：主控状态机、账户管理API、',
    '   支付逻辑API、存储层API、显示层API',
])

# Slide 6: Development Plan
add_slide('项目实施计划', [
    '◆ 第11-12周  立项开题',
    '   • 需求分析、方案论证 → 开题报告 + 答辩PPT',
    '',
    '◆ 第13周    电路设计',
    '   • 原理图设计、仿真验证 → 元件采购',
    '',
    '◆ 第14周    单元实现 → 中期检查',
    '   • 指纹驱动/UART → VGA显示 → 键盘 → 蜂鸣器',
    '',
    '◆ 第15-16周  系统联调',
    '   • 硬件模块集成 → 账户管理完整流程 → 支付交易流程',
    '',
    '◆ 第17周    功能验收',
    '   • 逐项功能测试 → 演示视频录制 → 文档提交',
    '',
    '◆ 第18周    总结报告',
    '   • 说明书(10000字+) → 源码整理 → 答辩PPT终稿',
])

# Slide 7: Component List & Innovation
add_slide('主要器件与创新点', [
    '◆ 主要器件清单',
    '   • Xilinx FPGA开发板 ×1  |  指纹模块(AS608) ×1',
    '   • VGA显示器 ×1          |  4×4矩阵键盘 ×1',
    '   • 有源蜂鸣器 ×1          |  SPI Flash ×1',
    '   • 杜邦线/面包板/电源     |  USB下载线 ×1',
    '',
    '◆ 拟实现的拓展创新',
    '   • SD卡大容量指纹库存储 — 突破Flash容量限制',
    '   • 交易记录查询功能     — 增强系统实用性',
    '   • UART串口上位机通信   — 支持PC端账户管理',
])

# Slide 8: Summary
add_slide('总结与展望', [
    '◆ 项目总结',
    '   • 方案成熟：基于成熟FPGA平台 + AS608指纹模块',
    '   • 验证充分：8个硬件模块全部通过Verilog仿真',
    '   • 架构清晰：硬件层(Verilog) + 应用层(C) 分层设计',
    '   • 功能完整：覆盖账户管理和支付交易的完整流程',
    '',
    '◆ 风险与应对',
    '   • 指纹模块兼容性 → 预留多品牌驱动适配接口',
    '   • VGA时序偏差   → 使用PLL生成精确像素时钟',
    '   • SPI Flash磨损  → 实现磨损均衡写入策略',
    '',
    '◆ 预期成果',
    '   • 完成功能完整的指纹识别支付系统硬件原型',
    '   • 撰写10000字以上课程设计说明书',
    '   • 输出全部源码、原理图、测试视频',
])

# Save PPT
ppt_path = os.path.join(output_dir, '开题答辩PPT_指纹支付的识别系统.pptx')
prs.save(ppt_path)
print(f"[OK] 开题答辩PPT已生成: {ppt_path}")

print("\nBoth documents generated successfully!")
