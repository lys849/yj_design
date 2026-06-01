# Nexys4 DDR â€? Fingerprint Payment System Board Test
# Board: Digilent Nexys4 DDR (XC7A100T-1CSG324C)
# Tests: keyboard, fingerprint sensor, buzzer, debug UART

# ============================================
# Clock â€? 100MHz single-ended oscillator
# ============================================
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

# ============================================
# Reset â€? CPU_RESET (C12, active low)
# ============================================
set_property PACKAGE_PIN C12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ============================================
# Debug UART â€? USB-UART bridge (FT2232HQ)
#   debug_tx = FPGA â†? PC (D4)
# ============================================
set_property PACKAGE_PIN D4 [get_ports debug_tx]
set_property IOSTANDARD LVCMOS33 [get_ports debug_tx]

# ============================================
# Keyboard 4Ã—4 â€? PMOD JB (8 signals)
# ============================================
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
set_property PACKAGE_PIN F13 [get_ports {kb_col[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[1]}]
set_property PACKAGE_PIN G13  [get_ports {kb_col[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[2]}]
set_property PACKAGE_PIN H16 [get_ports {kb_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[3]}]

# ============================================
# Fingerprint Sensor AS608 â€? PMOD JD (UART)
#   fp_sensor_tx = FPGA â†? sensor (JD3)
#   fp_sensor_rx = FPGA â†? sensor (JD4)
# ============================================
set_property PACKAGE_PIN G1 [get_ports fp_sensor_tx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_tx]
set_property PACKAGE_PIN G3 [get_ports fp_sensor_rx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_rx]

# ============================================
# Buzzer â€? PMOD JC (JC4 = Y1, JC5 = GND, JC6 = VCC)
# ============================================
set_property PACKAGE_PIN G6 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
