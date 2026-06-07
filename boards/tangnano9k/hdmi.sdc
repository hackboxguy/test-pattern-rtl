// test-pattern-rtl — Tang Nano 9K timing constraints.
// Default build is 640x480p60: serial (rPLL CLKOUT) = 126 MHz, pixel
// (rPLL CLKOUTD) = 25.2 MHz. The generated clocks propagate through the rPLL;
// only the 27 MHz input oscillator is constrained here.
create_clock -name clk_osc -period 37.037 [get_ports {clk}]
