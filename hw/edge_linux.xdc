# EDGE ZYNQ board I/O for the PetaLinux hardware (pins from the EDGE ZYNQ V3 board)

# LEDs D4..D7, left to right (bit 0 = D4)
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[1]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[2]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {leds_tri_o[3]}]

# Slide switches, numbered by position on the board so each one sits under its LED:
# left to right SW6, SW4, SW3, SW8 (bit 0 = SW6 under D4 ... bit 3 = SW8 under D7)
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[0]}]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[1]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[2]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {sws_tri_i[3]}]

# Push buttons (active high, with pull-downs), left to right SW7, SW5
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[0]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33 PULLDOWN true} [get_ports {btns_tri_i[1]}]
