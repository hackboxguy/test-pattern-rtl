// test-pattern-rtl — Tang Nano 9K timing constraints.
// Periods below are for the default 720p60 build (serial 371.25 MHz, pixel
// 74.25 MHz). Regenerate for other resolutions (see gowin_tmds_clkgen table).

// 27 MHz onboard oscillator
create_clock -name clk_osc -period 37.037 [get_ports {clk}]

// Generated clocks (names/nets may need adjusting to match your synth output)
create_clock -name serial_clk -period 2.6936 [get_nets {u_clk/serial_clk}]
create_clock -name pixel_clk  -period 13.468 [get_nets {u_clk/pixel_clk}]
