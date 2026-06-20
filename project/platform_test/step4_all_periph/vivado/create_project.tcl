# Step 4: 创建工程（全部外设引脚 + 全部源文件）
set project_name "step4_all_periph"
set project_dir  "./vivado_project"
set part         "xc7a100tcsg324-1"

catch {close_project -quiet}
if {[file exists $project_dir]} { file delete -force $project_dir }
create_project $project_name $project_dir -part $part
set_property target_language Verilog [current_project]

# 添加所有 RTL 源文件
set script_dir [file dirname [info script]]
set base [file normalize [file join $script_dir ../../..]]
add_files [list \
    [file join $script_dir ../ip/fp_payment_periph.v] \
    [file join $base modules/uart/rtl/uart_tx.v] \
    [file join $base modules/uart/rtl/uart_rx.v] \
    [file join $base modules/keyboard/rtl/keyboard_scan.v] \
    [file join $base modules/fingerprint/rtl/fingerprint_ctrl.v] \
    [file join $base modules/buzzer/rtl/buzzer_ctrl.v] \
]
update_compile_order -fileset sources_1

# XDC（全部引脚）
set xdc_content {
set_property PACKAGE_PIN E3 [get_ports sys_clock]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clock]
create_clock -period 10.000 -name sys_clk [get_ports sys_clock]
set_property PACKAGE_PIN C12 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
set_property PACKAGE_PIN D4 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PACKAGE_PIN C4 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]
set_property PACKAGE_PIN D14 [get_ports {kb_row[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[0]}]
set_property PACKAGE_PIN F16 [get_ports {kb_row[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[1]}]
set_property PACKAGE_PIN G16 [get_ports {kb_row[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[2]}]
set_property PACKAGE_PIN H14 [get_ports {kb_row[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[3]}]
set_property PACKAGE_PIN E16 [get_ports {kb_col[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[0]}]
set_property PULLUP true [get_ports {kb_col[0]}]
set_property PACKAGE_PIN F13 [get_ports {kb_col[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[1]}]
set_property PULLUP true [get_ports {kb_col[1]}]
set_property PACKAGE_PIN G13 [get_ports {kb_col[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[2]}]
set_property PULLUP true [get_ports {kb_col[2]}]
set_property PACKAGE_PIN H16 [get_ports {kb_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[3]}]
set_property PULLUP true [get_ports {kb_col[3]}]
set_property PACKAGE_PIN G1 [get_ports fp_sensor_tx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_tx]
set_property PACKAGE_PIN G3 [get_ports fp_sensor_rx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_rx]
set_property PULLUP true [get_ports fp_sensor_rx]
set_property PACKAGE_PIN G6 [get_ports buzzer_out]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer_out]
}

set xdc_file [file join $project_dir "nexys4_step4.xdc"]
set fp [open $xdc_file w]
puts $fp $xdc_content
close $fp
add_files -fileset constrs_1 $xdc_file

puts "工程创建完成，自动进入 Block Design..."
source [file join $script_dir create_bd.tcl]
