#=============================================================================
# Nexys4 DDR Pin Constraints — AS608 Fingerprint Demo (Pure Verilog)
# Board: Digilent Nexys4 DDR (XC7A100T-1CSG324C)
#=============================================================================

# ============================================================================
# Clock — 100 MHz on-board oscillator
# ============================================================================
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { sys_clk }];
create_clock -add -name sys_clk -period 10.00 -waveform {0 5} [get_ports { sys_clk }];

# ============================================================================
# Reset — CPU_RESET push-button (active low, pulled up to 3.3V when not pressed)
# ============================================================================
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { sys_resetn }];

# ============================================================================
# USB-UART (FTDI FT2232H) — to PC terminal @ 115200 bps
#   uart_dbg_txd : FPGA pin D4 → FTDI RXD → PC
#   uart_dbg_rxd : FTDI TXD → FPGA pin C4 ← PC
# ============================================================================
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { uart_dbg_txd }];
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { uart_dbg_rxd }];

# ============================================================================
# AS608 Fingerprint Sensor — PMOD JD
#
#   PMOD JD Pinout:
#     JD1=H4   JD7=H2
#     JD2=H1   JD8=G4
#     JD3=G1   JD9=G2
#     JD4=G3   JD10=F3
#     JD5=GND  JD11=GND
#     JD6=3.3V JD12=3.3V
#
#   Wiring:
#     JD3 (G1)  →  AS608 RXD  (module receive, white/yellow)
#     JD4 (G3)  ←  AS608 TXD  (module transmit, green/blue)
#     JD5 (GND) —  AS608 GND  (black)
#     JD6 (3.3V)—  AS608 VCC  (red)  ← MUST be 3.3V, not 5V!
# ============================================================================
set_property -dict { PACKAGE_PIN G1    IOSTANDARD LVCMOS33 } [get_ports { fp_sensor_tx }];   # FPGA→AS608
set_property -dict { PACKAGE_PIN G3    IOSTANDARD LVCMOS33 PULLUP true } [get_ports { fp_sensor_rx }];   # AS608→FPGA

# ============================================================================
# User LEDs — Status indicators
#   led[0] = H17 : System ready (on)
#   led[1] = K15 : Enrolling (blinks during enrollment)
#   led[2] = J13 : Identifying / Match success
#   led[3] = N14 : Error
# ============================================================================
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { led[2] }];
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }];

# ============================================================================
# Push Buttons
#   btn[0] = N17 (BTNC, center) : Start Enrollment
#   btn[1] = M18 (BTNU, up)     : Start Identification
# ============================================================================
set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];

# ============================================================================
# Configuration
# ============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLNONE [current_design]
