// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern — color_bars (PRD §8.2)
// Eight equal vertical bars across H_ACTIVE: white, yellow, cyan, green,
// magenta, red, blue, black. Approximate full-amplitude (100%) RGB bars — NOT
// PLUGE/IRE-exact (PRD §9 / FR-CLR-4). Bar boundaries are compile-time
// constants => pure comparators, no runtime division (FR-CORE-6).
module pat_color_bars #(
    parameter int COLOR_W  = 8,
    parameter int HCOORD_W = 12,
    parameter int H_ACTIVE = 640
)(
    input  logic [HCOORD_W-1:0]  x,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [COLOR_W-1:0] LO = '0;
    localparam logic [COLOR_W-1:0] HI = '1;

    localparam int B1 = (H_ACTIVE * 1) / 8;
    localparam int B2 = (H_ACTIVE * 2) / 8;
    localparam int B3 = (H_ACTIVE * 3) / 8;
    localparam int B4 = (H_ACTIVE * 4) / 8;
    localparam int B5 = (H_ACTIVE * 5) / 8;
    localparam int B6 = (H_ACTIVE * 6) / 8;
    localparam int B7 = (H_ACTIVE * 7) / 8;

    logic [2:0] bar;
    always_comb begin
        if      (x >= HCOORD_W'(B7)) bar = 3'd7;
        else if (x >= HCOORD_W'(B6)) bar = 3'd6;
        else if (x >= HCOORD_W'(B5)) bar = 3'd5;
        else if (x >= HCOORD_W'(B4)) bar = 3'd4;
        else if (x >= HCOORD_W'(B3)) bar = 3'd3;
        else if (x >= HCOORD_W'(B2)) bar = 3'd2;
        else if (x >= HCOORD_W'(B1)) bar = 3'd1;
        else                         bar = 3'd0;
    end

    always_comb begin
        unique case (bar)
            3'd0:    rgb = {HI, HI, HI};  // white
            3'd1:    rgb = {HI, HI, LO};  // yellow
            3'd2:    rgb = {LO, HI, HI};  // cyan
            3'd3:    rgb = {LO, HI, LO};  // green
            3'd4:    rgb = {HI, LO, HI};  // magenta
            3'd5:    rgb = {HI, LO, LO};  // red
            3'd6:    rgb = {LO, LO, HI};  // blue
            default: rgb = {LO, LO, LO};  // black (bar 7)
        endcase
    end
endmodule
