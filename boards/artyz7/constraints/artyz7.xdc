## SPDX-License-Identifier: MIT
## Arty Z7-20 HDMI source constraints for test-pattern-rtl.
## Pin mapping follows Digilent Arty-Z7-20-Master.xdc, HDMI source port J11.

## 125 MHz PL oscillator
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clk125 }]
create_clock -name clk125 -period 8.000 -waveform {0.000 4.000} [get_ports { clk125 }]

## Buttons, active high on Arty Z7
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]
set_property -dict { PACKAGE_PIN L19 IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]

## User LEDs
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN N16 IOSTANDARD LVCMOS33 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { led[3] }]

## HDMI TX source port J11: data ch0=blue, ch1=green, ch2=red
set_property -dict { PACKAGE_PIN K17 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_p[0] }]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_n[0] }]
set_property -dict { PACKAGE_PIN K19 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_p[1] }]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_n[1] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_p[2] }]
set_property -dict { PACKAGE_PIN H18 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_d_n[2] }]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_p }]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_n }]

## HDMI sideband. HPD is inverted on the source port; DDC/CEC are left high-Z.
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_hpdn }]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_scl }]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_sda }]
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { hdmi_tx_cec }]
