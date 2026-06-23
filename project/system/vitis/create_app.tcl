# Vitis/XSCT helper for the complete fingerprint payment application.
# Usage after exporting hardware from Vivado:
#   xsct project/system/vitis/create_app.tcl /path/to/fp_payment_system.xsa

if {$argc < 1} {
    puts "Usage: xsct create_app.tcl <hardware.xsa> ?workspace_dir?"
    exit 1
}

set xsa_file [file normalize [lindex $argv 0]]
if {$argc >= 2} {
    set ws_dir [file normalize [lindex $argv 1]]
} else {
    set ws_dir [file normalize "./vitis_workspace"]
}
set script_dir [file dirname [info script]]
set sw_dir [file normalize [file join $script_dir ../sw]]

setws $ws_dir

platform create -name fp_payment_platform -hw $xsa_file -proc microblaze_0 -os standalone
platform active fp_payment_platform
platform generate

app create -name fp_payment_app \
    -platform fp_payment_platform \
    -domain standalone_domain \
    -template {Empty Application}

importsources -name fp_payment_app -path $sw_dir
app build -name fp_payment_app

puts "Vitis application built in $ws_dir"
