# Step 3: Block Design — MicroBlaze + GPIO + UART + 自定义键盘外设
# 使用 Module Reference 方式添加自定义外设（需先执行 create_project.tcl 添加源文件）

create_bd_design "system"

# ============================================
# 基础系统（同 Step 2）
# ============================================
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config { \
    axi_intc {0} axi_periph {Enabled} cache {None} \
    clk {New Clocking Wizard (100 MHz)} \
    debug_module {Debug Only} ecc {None} local_mem {128KB} preset {None} \
} [get_bd_cells microblaze_0]

# 修正时钟输入: 差分 → 单端（Vivado 2025.2 默认创建差分输入）
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

# 复位极性修正
set rst_cell [lindex [get_bd_cells -filter {VLNV =~ *proc_sys_reset*}] 0]
set old_ports [get_bd_ports -quiet reset]
if {[llength $old_ports] > 0} {
    set old_net [get_bd_nets -quiet -of_objects [get_bd_pins $rst_cell/ext_reset_in]]
    if {[llength $old_net] > 0} { delete_bd_objs $old_net }
    delete_bd_objs $old_ports
}
create_bd_port -dir I -type rst reset_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports reset_n]
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 reset_inverter
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {not}] [get_bd_cells reset_inverter]
connect_bd_net [get_bd_ports reset_n] [get_bd_pins reset_inverter/Op1]
connect_bd_net [get_bd_pins reset_inverter/Res] [get_bd_pins $rst_cell/ext_reset_in]

# AXI GPIO（LED）
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_ALL_OUTPUTS {1}] [get_bd_cells axi_gpio_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Master {/microblaze_0 (Periph)} Slave {/axi_gpio_0/S_AXI} \
    intc_ip {New AXI Interconnect} master_apm {0} \
} [get_bd_intf_pins axi_gpio_0/S_AXI]
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o] [get_bd_ports led]

# AXI UART Lite
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0
set_property -dict [list CONFIG.C_BAUDRATE {115200}] [get_bd_cells axi_uartlite_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Master {/microblaze_0 (Periph)} Slave {/axi_uartlite_0/S_AXI} \
    intc_ip {/microblaze_0_axi_periph} master_apm {0} \
} [get_bd_intf_pins axi_uartlite_0/S_AXI]
create_bd_port -dir O uart_tx
create_bd_port -dir I uart_rx
connect_bd_net [get_bd_pins axi_uartlite_0/tx] [get_bd_ports uart_tx]
connect_bd_net [get_bd_ports uart_rx] [get_bd_pins axi_uartlite_0/rx]

# ============================================
# 新增: 键盘自定义外设 (Module Reference)
# ============================================
create_bd_cell -type module -reference kb_periph kb_periph_0

# 连接 AXI 接口到 MicroBlaze 总线
# 注意: Module Reference 的 AXI 接口可能需要手动连接
# 先尝试自动连接，如果失败则需手动操作（见 README_manual.md）
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Master {/microblaze_0 (Periph)} Slave {/kb_periph_0/S_AXI} \
    intc_ip {/microblaze_0_axi_periph} master_apm {0} \
} [get_bd_intf_pins kb_periph_0/S_AXI]

# 引出键盘端口
create_bd_port -dir O -from 3 -to 0 kb_row
create_bd_port -dir I -from 3 -to 0 kb_col
connect_bd_net [get_bd_pins kb_periph_0/kb_row] [get_bd_ports kb_row]
connect_bd_net [get_bd_ports kb_col] [get_bd_pins kb_periph_0/kb_col]

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

puts "Block Design 完成（含键盘外设）→ Generate Bitstream"
