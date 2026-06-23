# Fingerprint board test project creator
# Default top is fp_init_verify_top, the golden AS608 init verification test.
# To build the minimal fingerprint_ctrl test instead:
#   set ::env(FP_TOP) fp_test_top
#   source create_project.tcl

set project_name "fingerprint_board_test"
set project_dir  "./vivado_project"
set part         "xc7a100tcsg324-1"

if {[info exists ::env(FP_TOP)]} {
    set top_name $::env(FP_TOP)
} else {
    set top_name "fp_init_verify_top"
}

set script_dir [file dirname [info script]]
set project_root [file normalize [file join $script_dir ../../..]]

switch -- $top_name {
    fp_init_verify_top {
        set top_file [file join $script_dir fp_init_verify_top.v]
        set xdc_file [file join $script_dir fp_init_verify.xdc]
        set extra_sources [list]
    }
    fp_test_top {
        set top_file [file join $script_dir fp_test_top.v]
        set xdc_file [file join $script_dir fp_test.xdc]
        set extra_sources [list \
            [file join $project_root modules/fingerprint/rtl/fingerprint_ctrl.v] \
        ]
    }
    default {
        error "Unsupported FP_TOP '$top_name'. Use fp_init_verify_top or fp_test_top."
    }
}

catch {close_project -quiet}
if {[file exists $project_dir]} { file delete -force $project_dir }
create_project $project_name $project_dir -part $part
set_property target_language Verilog [current_project]

add_files [concat [list \
    $top_file \
    [file join $project_root modules/uart/rtl/uart_tx.v] \
    [file join $project_root modules/uart/rtl/uart_rx.v] \
] $extra_sources]
set_property top $top_name [current_fileset]
update_compile_order -fileset sources_1

add_files -fileset constrs_1 $xdc_file

puts "Fingerprint board test project created."
puts "Top: $top_name"
puts "Next: Run Synthesis -> Run Implementation -> Generate Bitstream -> Program Device"
