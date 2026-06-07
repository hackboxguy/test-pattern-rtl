// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — gowin_tmds_clkgen
//
// 27 MHz -> Gowin rPLL: CLKOUT = 5x pixel (serial), CLKOUTD = CLKOUT/5 (pixel).
// Both clocks come from one rPLL via its CLKOUTD divider (SDIV=5), avoiding a
// separate CLKDIV cell -- classic nextpnr-gowin 0.6 cannot place CLKDIV here.
// rPLL params follow the apicula DVI example (examples/DVI/pll480.v). Validated
// via the open Gowin flow (synth_gowin + nextpnr-gowin + gowin_pack).
//
// rPLL: fCLKOUT = 27MHz*(FBDIV_SEL+1)/(IDIV_SEL+1);  fVCO = fCLKOUT*ODIV_SEL
//       (VCO ~400..1200 MHz on GW1NR-9C).
//
//   mode         pixel/serial    IDIV FBDIV ODIV  VCO    status
//   640x480p60   25.2/126.0 MHz   2    13    4    504   default (apicula PLL480)
//   1280x720p60  74.25/371.25     3    54    2    742   720p (must-pass)
//   1920x1080p60 148.5/742.5      —    —     —    —     out of VCO range (PRD risk)
module gowin_tmds_clkgen #(
    parameter IDIV_SEL  = 2,
    parameter FBDIV_SEL = 13,
    parameter ODIV_SEL  = 4
)(
    input  logic clk27,        // 27 MHz oscillator
    input  logic resetn,       // active-low
    output logic serial_clk,   // 5x pixel clock (OSER10 FCLK)
    output logic pixel_clk,    // pixel clock (OSER10 PCLK, video domain)
    output logic pll_lock
);
    wire clkoutp_o, clkoutd3_o;

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
        .DYN_SDIV_SEL    (5),       .CLKOUTD_SRC("CLKOUT"),   .CLKOUTD3_SRC("CLKOUT"),
        .DEVICE          ("GW1NR-9C")   // actual Tang Nano 9K part (nextpnr checks this)
    ) u_pll (
        .CLKOUT  (serial_clk),   // 5x pixel
        .CLKOUTD (pixel_clk),    // CLKOUT / SDIV(5) = pixel clock
        .LOCK    (pll_lock),
        .CLKOUTP (clkoutp_o), .CLKOUTD3(clkoutd3_o),
        .RESET   (1'b0), .RESET_P(1'b0),
        .CLKIN   (clk27), .CLKFB(1'b0),
        .FBDSEL  (6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
        .PSDA    (4'b0), .DUTYDA(4'b0), .FDLY(4'b0)
    );

    // resetn currently unused (CLKDIV removed); kept on the port for symmetry.
    wire _unused = &{1'b0, resetn};
endmodule
