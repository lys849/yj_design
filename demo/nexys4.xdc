# Nexys4 DDR Pin Constraints — Fingerprint Payment System
# Board: Digilent Nexys4 DDR (XC7A100T-1CSG324C)
# Reference: N4.pdf (Nexys 4 Reference Manual) + Digilent Master XDC

# ============================================
# Clock — 100MHz single-ended oscillator
# ============================================
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

# ============================================
# Reset — CPU_RESET button (active-low, pressed=0)
# ============================================
set_property PACKAGE_PIN C12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# ============================================
# VGA — 4-bit per color (12-bit total, 4096 colors)
# ============================================
set_property PACKAGE_PIN A3 [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]
set_property PACKAGE_PIN B4 [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5 [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]
set_property PACKAGE_PIN A4 [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]

set_property PACKAGE_PIN C6 [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A5 [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]
set_property PACKAGE_PIN B6 [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]
set_property PACKAGE_PIN A6 [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]

set_property PACKAGE_PIN B7 [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]
set_property PACKAGE_PIN C7 [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]
set_property PACKAGE_PIN A7 [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]
set_property PACKAGE_PIN C8 [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]

set_property PACKAGE_PIN D8 [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]
set_property PACKAGE_PIN A9 [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

# ============================================
# SPI Flash — S25FL128S (standard SPI mode)
# ============================================
set_property PACKAGE_PIN L13 [get_ports flash_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports flash_cs_n]
set_property PACKAGE_PIN L16 [get_ports flash_clk]
set_property IOSTANDARD LVCMOS33 [get_ports flash_clk]
set_property PACKAGE_PIN K17 [get_ports flash_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports flash_mosi]
set_property PACKAGE_PIN K18 [get_ports flash_miso]
set_property IOSTANDARD LVCMOS33 [get_ports flash_miso]

# ============================================
# LEDs — first 4 of 16 user LEDs (active-high)
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
#   debug_tx = FPGA output → PC receive (pin D4)
#   debug_rx = FPGA input  ← PC transmit (pin C4)
# ============================================
set_property PACKAGE_PIN D4 [get_ports debug_tx]
set_property IOSTANDARD LVCMOS33 [get_ports debug_tx]
set_property PACKAGE_PIN C4 [get_ports debug_rx]
set_property IOSTANDARD LVCMOS33 [get_ports debug_rx]

# ============================================
# Keyboard 4×4 — PMOD JB (8 signals, Nexys4 DDR)
#   kb_row[3:0] = FPGA outputs (row scan)
#   kb_col[3:0] = FPGA inputs  (column read)
#   Wiring: JB1..JB4 = kb_row[0..3], JB7..JB10 = kb_col[0..3]
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
set_property PACKAGE_PIN G13 [get_ports {kb_col[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[2]}]
set_property PACKAGE_PIN H16 [get_ports {kb_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kb_col[3]}]

# ============================================
# Fingerprint Sensor (AS608) UART — PMOD JD
#   fp_sensor_tx = FPGA → sensor (JD3)
#   fp_sensor_rx = FPGA ← sensor (JD4)
# ============================================
set_property PACKAGE_PIN G1 [get_ports fp_sensor_tx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_tx]
set_property PACKAGE_PIN G3 [get_ports fp_sensor_rx]
set_property IOSTANDARD LVCMOS33 [get_ports fp_sensor_rx]

# ============================================
# Buzzer — PMOD JC (JC4 = G6, JC5 = GND, JC6 = VCC)
# ============================================
set_property PACKAGE_PIN G6 [get_ports buzzer]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer]

# ============================================
# Pull-ups for floating inputs
# ============================================
set_property PULLUP true [get_ports fp_sensor_rx]
set_property PULLUP true [get_ports {kb_col[0]}]
set_property PULLUP true [get_ports {kb_col[1]}]
set_property PULLUP true [get_ports {kb_col[2]}]
set_property PULLUP true [get_ports {kb_col[3]}]
