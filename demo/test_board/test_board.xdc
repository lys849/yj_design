# Nexys4 DDR Board Self-Test — Vivado Pin Constraints
# Board: Digilent Nexys4 DDR (XC7A100T-1CSG324C)
# Tests: LEDs, USB-UART, BTNC button — no external peripherals needed

# ============================================
# Clock — 100MHz single-ended oscillator
# ============================================
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

# ============================================
# Reset — CPU_RESET (C12, active low)
# ============================================
set_property PACKAGE_PIN C12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ============================================
# BTNC — Center pushbutton (D9, active high)
# ============================================
set_property PACKAGE_PIN D9 [get_ports btnc]
set_property IOSTANDARD LVCMOS33 [get_ports btnc]

# ============================================
# LEDs — first 4 of 16 user LEDs (active high)
# ============================================
set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

# ============================================
# Debug UART — USB-UART bridge (FT2232HQ)
#   debug_tx = FPGA → PC (D4)
# ============================================
set_property PACKAGE_PIN D4 [get_ports debug_tx]
set_property IOSTANDARD LVCMOS33 [get_ports debug_tx]
