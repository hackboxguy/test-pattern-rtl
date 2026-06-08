// test-pattern-rtl — Tang Nano 9K timing constraints.
// The fabric pixel-clock domain is constrained per-resolution by the build flow
// (flow/build.sh passes `nextpnr-himbaechel --freq <pixel MHz>`), so P&R is
// timing-driven at the real pixel clock (25.2 / 74.25 MHz). This file just
// pins the 27 MHz input oscillator.
create_clock -name clk_osc -period 37.037 [get_ports {clk}]
