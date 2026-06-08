// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern — grid / crosshatch (PRD §8.2)
// White grid lines on black, pitch = 2^PITCH_LOG2, line width LINE_W, plus a
// closing border on all four active edges (the right/bottom edges aren't pitch
// multiples for non-power-of-two resolutions, so they're added explicitly).
// Power-of-two pitch keeps position-within-cell a bit-mask (no modulo/division).
module pat_grid #(
    parameter int COLOR_W    = 8,
    parameter int HCOORD_W   = 12,
    parameter int VCOORD_W   = 12,
    parameter int H_ACTIVE   = 640,
    parameter int V_ACTIVE   = 480,
    parameter int PITCH_LOG2 = 5,   // 32-pixel grid
    parameter int LINE_W     = 1
)(
    input  logic [HCOORD_W-1:0]  x,
    input  logic [VCOORD_W-1:0]  y,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [COLOR_W-1:0] LO    = '0;
    localparam logic [COLOR_W-1:0] HI    = '1;
    localparam int                 PITCH = (1 << PITCH_LOG2);

    logic on_line;
    assign on_line = ((x & HCOORD_W'(PITCH-1)) < HCOORD_W'(LINE_W)) ||  // vertical lines (incl. left)
                     ((y & VCOORD_W'(PITCH-1)) < VCOORD_W'(LINE_W)) ||  // horizontal lines (incl. top)
                     (x >= HCOORD_W'(H_ACTIVE - LINE_W))            ||  // right border
                     (y >= VCOORD_W'(V_ACTIVE - LINE_W));               // bottom border
    assign rgb = on_line ? {HI, HI, HI} : {LO, LO, LO};
endmodule
