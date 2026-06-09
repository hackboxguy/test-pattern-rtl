// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern — ramp (PRD §8.2)
// Luminance ramp 0 -> full-scale across DIM (the active dimension). Instantiate
// once per axis (coord = x0 for ramp_h, y for ramp_v). Uses a precomputed
// reciprocal (INV, elaboration-time) and a constant multiply — NO runtime
// division in the pixel path (FR-CORE-6 / PRD §9). DIM is compile-time (Mode A).
module pat_ramp #(
    parameter int COLOR_W = 8,
    parameter int COORD_W = 12,
    parameter int DIM     = 640,   // active pixels/lines along this axis
    parameter int FRAC    = 12     // reciprocal fractional bits
)(
    input  logic                   clk,
    input  logic                   rst,    // active-high, synchronous
    input  logic [COORD_W-1:0]   coord,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [COLOR_W-1:0] HI = '1;
    // INV ≈ 2^(COLOR_W+FRAC) / DIM, rounded.
    localparam int INV   = ((1 << (COLOR_W + FRAC)) + (DIM / 2)) / DIM;
    localparam int PRODW = COORD_W + COLOR_W + FRAC;

    logic [PRODW-1:0]           prod_q;
    logic [COORD_W+COLOR_W-1:0] shifted;   // prod / 2^FRAC
    logic [COLOR_W-1:0]         val;

    always_ff @(posedge clk) begin
        if (rst) prod_q <= '0;
        else     prod_q <= coord * PRODW'(INV);
    end

    assign shifted = prod_q[PRODW-1:FRAC];
    // Saturate if the scaled value spilled above the channel range.
    assign val     = (|shifted[COORD_W+COLOR_W-1:COLOR_W]) ? HI : shifted[COLOR_W-1:0];
    assign rgb     = {val, val, val};

    // Low FRAC bits of the product are intentionally discarded by the >>FRAC.
    logic _unused_frac;
    assign _unused_frac = &{1'b0, prod_q[FRAC-1:0]};
endmodule
