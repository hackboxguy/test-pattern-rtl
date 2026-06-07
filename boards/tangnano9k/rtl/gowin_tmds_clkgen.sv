// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — gowin_tmds_clkgen
//
// Generates the TMDS serial clock (5x pixel) and the pixel clock from the 27 MHz
// onboard oscillator, using Gowin rPLL + CLKDIV(/5). Instantiates GW1NR-9C
// primitives -> NOT Verilator-lintable, NOT validated in this repo.
//
// !! UNVERIFIED. The rPLL divider settings MUST be generated/confirmed with the
//    Gowin Clock Calculator / IP generator for the target pixel clock, and the
//    rPLL port/param list checked against the Gowin Primitives User Guide.
//
// rPLL:  fCLKOUT = 27MHz * (FBDIV_SEL+1)/(IDIV_SEL+1);  fVCO = fCLKOUT*ODIV_SEL
//        (VCO must stay ~400..1200 MHz on GW1NR-9C).
//
//   mode          pixel     serial(5x)   IDIV_SEL  FBDIV_SEL  ODIV_SEL   VCO
//   640x480p60    25.2 MHz  126.0 MHz       2 (/3)    13 (x14)    8       1008  (ok)
//   1280x720p60   74.25     371.25          3 (/4)    54 (x55)    2        742  (ok, default)
//   1920x1080p60  148.5     742.5           1 (/2)    54 (x55)    2       1485  (OUT OF RANGE)
//
//   1080p60 (742.5 MHz serial) exceeds the rPLL VCO range with these dividers,
//   matching the PRD §11/§18 risk -- 1080p is a stretch on the open Gowin flow
//   and needs special clocking (or is simply not reachable here). 720p60 is the
//   must-pass target; defaults below are 720p60.
module gowin_tmds_clkgen #(
    parameter IDIV_SEL  = 3,
    parameter FBDIV_SEL = 54,
    parameter ODIV_SEL  = 2
)(
    input  logic clk27,        // 27 MHz oscillator
    input  logic resetn,       // active-low
    output logic serial_clk,   // 5x pixel clock (OSER10 FCLK)
    output logic pixel_clk,    // pixel clock (OSER10 PCLK, video domain)
    output logic pll_lock
);
    rPLL #(
        .FCLKIN     ("27"),
        .IDIV_SEL   (IDIV_SEL),
        .FBDIV_SEL  (FBDIV_SEL),
        .ODIV_SEL   (ODIV_SEL),
        .DYN_SDIV_SEL(2),
        .DEVICE     ("GW1NR-9C")
    ) u_pll (
        .CLKIN  (clk27),
        .CLKOUT (serial_clk),
        .LOCK   (pll_lock),
        .RESET  (1'b0),
        .RESET_P(1'b0),
        .CLKFB  (1'b0),
        .FBDSEL (6'b0), .IDSEL(6'b0), .ODSEL(6'b0),
        .PSDA   (4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
        .CLKOUTP(), .CLKOUTD(), .CLKOUTD3()
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN   ("false")
    ) u_div (
        .CLKOUT(pixel_clk),
        .HCLKIN(serial_clk),
        .RESETN(resetn),
        .CALIB (1'b0)
    );
endmodule
