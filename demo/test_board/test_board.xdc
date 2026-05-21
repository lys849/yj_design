# Nexys4 DDR — Fingerprint Payment System Board Test
# Board: Digilent Nexys4 DDR (XC7A100T-1CSG324C)
# Tests: keyboard, fingerprint sensor, buzzer, debug UART

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
# Debug UART — USB-UART bridge (FT2232HQ)
#   debug_tx = FPGA → PC (D4)
# ============================================
set_property PACKAGE_PIN D4 [get_ports debug_tx]
set_property IOSTANDARD LVCMOS33 [get_ports debug_tx]

# ============================================
# Keyboard 4×4 — PMOD JB (8 signals)
# ============================================
set_property PACKAGE_PIN G14 [get_ports {kb_row[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[0]}]
set_property PACKAGE_PIN P15 [get_ports {kb_row[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[1]}]
set_property PACKAGE_PIN V11 [get_ports {kb_row[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[2]}]
set_property PACKAGE_PIN V15 [get_ports {kb_row[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_row[3]}]

set_property PACKAGE_PIN K16 [get_ports {kb_col[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[0]}]
set_property PACKAGE_PIN R16 [get_ports {kb_col[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[1]}]
set_property PACKAGE_PIN T9  [get_ports {kb_col[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[2]}]
set_property PACKAGE_PIN U11 [get_ports {kb_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[3]}]

# ============================================
# Fingerprint Sensor AS608 — PMOD JD (UART)
#   fp_sensor_tx = FPGA → sensor (JD3)
#   fp_sensor_rx = FPGA ← sensor (JD4)
# ============================================
set_property PACKAGE_PIN G1 [get_ports fp_sensor_tx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_tx]
set_property PACKAGE_PIN G3 [get_ports fp_sensor_rx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_rx]

# ============================================
# Buzzer — PMOD JC (JC4 = Y1, JC5 = GND, JC6 = VCC)
# ============================================
set_property PACKAGE_PIN Y1 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]
