# Create the complete fingerprint payment system Vivado project.

set project_name "fp_payment_system"
set project_dir  "./vivado_project"
set part         "xc7a100tcsg324-1"

catch {close_project -quiet}
if {[file exists $project_dir]} { file delete -force $project_dir }
create_project $project_name $project_dir -part $part
set_property target_language Verilog [current_project]

set script_dir [file dirname [info script]]
set system_dir [file normalize [file join $script_dir ..]]
set project_root [file normalize [file join $system_dir ..]]

add_files [list \
    [file join $system_dir ip/fp_payment_periph.v] \
    [file join $system_dir rtl/fp_payment_system_top.v] \
    [file join $project_root modules/uart/rtl/uart_tx.v] \
    [file join $project_root modules/uart/rtl/uart_rx.v] \
    [file join $project_root modules/keyboard/rtl/keyboard_scan.v] \
    [file join $project_root modules/fingerprint/rtl/fingerprint_ctrl.v] \
    [file join $project_root modules/buzzer/rtl/buzzer_ctrl.v] \
    [file join $project_root modules/vga/rtl/vga_ctrl.v] \
    [file join $project_root modules/vga/rtl/vga_text.v] \
]
add_files -fileset constrs_1 [file join $system_dir constraints/nexys4_system.xdc]

update_compile_order -fileset sources_1
source [file join $script_dir create_bd.tcl]

set_property top fp_payment_system_top [current_fileset]
update_compile_order -fileset sources_1

puts "Complete system project created. Generate bitstream, then export hardware for Vitis."
