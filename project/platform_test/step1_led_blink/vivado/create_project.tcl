# Step 1: 创建 Vivado 工程
# 用法: 在 Vivado TCL Console 中执行
#   cd <本文件所在目录的上一级，即 step1_led_blink/>
#   source vivado/create_project.tcl

set project_name "step1_led_blink"
set project_dir  "./vivado_project"
set part         "xc7a100tcsg324-1"

# 如果工程已存在则删除重建
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

create_project $project_name $project_dir -part $part
set_property target_language Verilog [current_project]

# 添加约束文件（时钟 + 复位 + LED）
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
}

set xdc_file [file join $project_dir "nexys4_step1.xdc"]
set fp [open $xdc_file w]
puts $fp $xdc_content
close $fp
add_files -fileset constrs_1 $xdc_file

puts "========================================"
puts " 工程创建完成: $project_name"
puts " 下一步: source vivado/create_bd.tcl"
puts "========================================"
