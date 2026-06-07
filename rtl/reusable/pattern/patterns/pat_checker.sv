// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern — checker (PRD §8.2)
// Black/white checkerboard with power-of-two block size (BLOCK_LOG2). Set
// BLOCK_LOG2=0 for the 1-pixel checkerboard (pixel-clock integrity test). Pure
// bit-select — no multiply/division/modulo (FR-CORE-6).
module pat_checker #(
    parameter int COLOR_W    = 8,
    parameter int HCOORD_W   = 12,
    parameter int VCOORD_W   = 12,
    parameter int BLOCK_LOG2 = 4    // 0 => 1-pixel checker
)(
    input  logic [HCOORD_W-1:0]  x,
    input  logic [VCOORD_W-1:0]  y,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [COLOR_W-1:0] LO = '0;
    localparam logic [COLOR_W-1:0] HI = '1;

    logic cb;
    assign cb  = x[BLOCK_LOG2] ^ y[BLOCK_LOG2];
    assign rgb = cb ? {HI, HI, HI} : {LO, LO, LO};
endmodule
