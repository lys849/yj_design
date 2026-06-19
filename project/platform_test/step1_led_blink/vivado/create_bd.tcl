# Step 1: 创建 Block Design — MicroBlaze + AXI GPIO(LED)
# 用法: source vivado/create_bd.tcl（需先执行 create_project.tcl）

# ============================================
# 1. 创建 Block Design
# ============================================
create_bd_design "system"

# ============================================
# 2. 添加 MicroBlaze 并运行自动化配置
# ============================================
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0

# Block Automation: 自动创建 BRAM(128KB) + 调试模块 + 时钟向导 + 复位模块
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { \
    axi_intc {0} \
    axi_periph {Enabled} \
    cache {None} \
    clk {New Clocking Wizard (100 MHz)} \
    debug_module {Debug Only} \
    ecc {None} \
    local_mem {128KB} \
    preset {None} \
} [get_bd_cells microblaze_0]

# ============================================
# 2.1 修正时钟输入: 差分 → 单端
#     Nexys4 DDR 板载 100MHz 单端时钟 (E3)
#     Vivado 2025.2 的 Block Automation 默认创建差分输入，需手动修正
# ============================================
set clk_wiz [get_bd_cells -filter {VLNV =~ *clk_wiz*}]

set diff_intf [get_bd_intf_ports -quiet -filter {VLNV =~ *diff_clock*}]
if {[llength $diff_intf] > 0} {
    set diff_nets [get_bd_intf_nets -quiet -of_objects $diff_intf]
    if {[llength $diff_nets] > 0} { delete_bd_objs $diff_nets }
    delete_bd_objs $diff_intf
}

set_property -dict [list \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {100.000} \
] $clk_wiz

create_bd_port -dir I -type clk -freq_hz 100000000 sys_clock
connect_bd_net [get_bd_ports sys_clock] [get_bd_pins $clk_wiz/clk_in1]

# ============================================
# 3. 修正复位极性
#    Nexys4 DDR 的 CPU_RESET 按钮是低有效（按下=0）
#    但 proc_sys_reset 的 ext_reset_in 期望高有效
#    解决方案: 插入一个反相器
# ============================================

# 找到自动化创建的复位模块和外部复位端口
set rst_cells [get_bd_cells -quiet -filter {VLNV =~ *proc_sys_reset*}]
set rst_cell [lindex $rst_cells 0]

# 找到并断开自动生成的 reset 外部端口
set old_reset_ports [get_bd_ports -quiet reset]
if {[llength $old_reset_ports] > 0} {
    set old_net [get_bd_nets -quiet -of_objects [get_bd_pins $rst_cell/ext_reset_in]]
    if {[llength $old_net] > 0} {
        delete_bd_objs $old_net
    }
    delete_bd_objs $old_reset_ports
}

# 创建低有效复位端口
create_bd_port -dir I -type rst reset_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports reset_n]

# 添加反相器
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_inverter
set_property -dict [list \
    CONFIG.C_SIZE {1} \
    CONFIG.C_OPERATION {not} \
    CONFIG.LOGO_FILE {data/sym_notgate.png} \
] [get_bd_cells reset_inverter]

# 连接: reset_n → 反相器 → proc_sys_reset.ext_reset_in
connect_bd_net [get_bd_ports reset_n] [get_bd_pins reset_inverter/Op1]
connect_bd_net [get_bd_pins reset_inverter/Res] [get_bd_pins $rst_cell/ext_reset_in]

# ============================================
# 4. 添加 AXI GPIO（4-bit LED 输出）
# ============================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {4} \
    CONFIG.C_ALL_OUTPUTS {1} \
] [get_bd_cells axi_gpio_0]

# 连接 AXI GPIO 到 MicroBlaze 总线
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} \
    Clk_slave {Auto} \
    Clk_xbar {Auto} \
    Master {/microblaze_0 (Periph)} \
    Slave {/axi_gpio_0/S_AXI} \
    ddr_seg {Auto} \
    intc_ip {New AXI Interconnect} \
    master_apm {0} \
} [get_bd_intf_pins axi_gpio_0/S_AXI]

# 引出 LED 端口
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_ports led]

# ============================================
# 5. 验证、保存、生成 Wrapper
# ============================================
regenerate_bd_layout
validate_bd_design
save_bd_design

make_wrapper -files [get_files system.bd] -top
set wrapper_file [glob -nocomplain [get_property DIRECTORY [current_project]]/*.srcs/sources_1/bd/system/hdl/system_wrapper.v]
if {$wrapper_file ne ""} {
    add_files -norecurse $wrapper_file
    update_compile_order -fileset sources_1
}

puts "========================================"
puts " Block Design 创建完成！"
puts " 你应该能在 Diagram 窗口看到完整的连线图"
puts " 下一步: 点击左侧 Flow Navigator → Generate Bitstream"
puts "========================================"
