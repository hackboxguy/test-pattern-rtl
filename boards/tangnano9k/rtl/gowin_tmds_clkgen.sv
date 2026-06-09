// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — gowin_tmds_clkgen
//
// 27 MHz -> Gowin rPLL (CLKOUT = 5x pixel serial clock) -> CLKDIV(/5) -> pixel
// clock. This is the known-good apicula DVI clocking (examples/DVI/pll480.v +
// CLKDIV) and REQUIRES nextpnr-himbaechel: the older Debian nextpnr-gowin 0.6
// cannot place CLKDIV (apicula's own CLKDIV example fails on it too). Build via
// OSS CAD Suite (nextpnr-himbaechel + modern yosys). Not Verilator-lintable.
//
// rPLL: fCLKOUT = 27MHz*(FBDIV_SEL+1)/(IDIV_SEL+1);  fVCO = fCLKOUT*ODIV_SEL.
//
// Dividers are passed in by the board top (selected per RES=/PANEL= in build.sh),
// not fixed here. Reference points (serial = 5 x pixel):
//   mode          pixel/serial      IDIV FBDIV ODIV  status
//   640x480p60    25.2 /126.0 MHz    2    13    4    clean
//   800x600p60    ~40  /~200 MHz     4    36    4    clean
//   1024x768p60   ~65  /~325 MHz     0    11    2    clean (highest confirmed)
//   1280x720p60   74.25/371.25 MHz   3    54    2    above ELVDS cliff (artifacts)
//   1920x1080p60  148.5/742.5 MHz    —    —     —    not buildable (>600 MHz CLKOUT)
module gowin_tmds_clkgen #(
    parameter IDIV_SEL  = 2,
    parameter FBDIV_SEL = 13,
    parameter ODIV_SEL  = 4
)(
    input  logic clk27,        // 27 MHz oscillator
    input  logic resetn,       // active-low (unused; CLKDIV gated by pll_lock)
    output logic serial_clk,   // 5x pixel clock (OSER10 FCLK)
    output logic pixel_clk,    // pixel clock (OSER10 PCLK, video domain)
    output logic pll_lock
);
    wire clkoutp_o, clkoutd_o, clkoutd3_o;

    rPLL #(
        .FCLKIN          ("27"),
        .DYN_IDIV_SEL    ("false"), .IDIV_SEL (IDIV_SEL),
        .DYN_FBDIV_SEL   ("false"), .FBDIV_SEL(FBDIV_SEL),
        .DYN_ODIV_SEL    ("false"), .ODIV_SEL (ODIV_SEL),
        .PSDA_SEL        ("0000"),  .DYN_DA_EN("true"), .DUTYDA_SEL("1000"),
        .CLKOUT_FT_DIR   (1'b1),    .CLKOUTP_FT_DIR(1'b1),
        .CLKOUT_DLY_STEP (0),       .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL       ("internal"),
        .CLKOUT_BYPASS   ("false"), .CLKOUTP_BYPASS("false"), .CLKOUTD_BYPASS("false"),
        .DYN_SDIV_SEL    (2),       .CLKOUTD_SRC("CLKOUT"),   .CLKOUTD3_SRC("CLKOUT"),
        .DEVICE          ("GW1N-9C")
    ) u_pll (
        .CLKOUT  (serial_clk),
        .LOCK    (pll_lock),
        .CLKOUTP (clkoutp_o), .CLKOUTD(clkoutd_o), .CLKOUTD3(clkoutd3_o),
        .RESET   (1'b0), .RESET_P(1'b0),
        .CLKIN   (clk27), .CLKFB(1'b0),
        .FBDSEL  (6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
        .PSDA    (4'b0), .DUTYDA(4'b0), .FDLY(4'b0)
    );

    CLKDIV #(.DIV_MODE("5")) u_div (
        .CLKOUT(pixel_clk),
        .HCLKIN(serial_clk),
        .RESETN(pll_lock)
    );

    wire _unused = &{1'b0, resetn, clkoutp_o, clkoutd_o, clkoutd3_o};
endmodule
