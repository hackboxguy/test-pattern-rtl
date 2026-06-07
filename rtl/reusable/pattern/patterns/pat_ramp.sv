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
    input  logic [COORD_W-1:0]   coord,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [COLOR_W-1:0] HI = '1;
    // INV ≈ 2^(COLOR_W+FRAC) / DIM, rounded.
    localparam int INV   = ((1 << (COLOR_W + FRAC)) + (DIM / 2)) / DIM;
    localparam int PRODW = COORD_W + COLOR_W + FRAC;

    logic [PRODW-1:0]           prod;
    logic [COORD_W+COLOR_W-1:0] shifted;   // prod / 2^FRAC
    logic [COLOR_W-1:0]         val;

    assign prod    = coord * PRODW'(INV);
    assign shifted = prod[PRODW-1:FRAC];
    // Saturate if the scaled value spilled above the channel range.
    assign val     = (|shifted[COORD_W+COLOR_W-1:COLOR_W]) ? HI : shifted[COLOR_W-1:0];
    assign rgb     = {val, val, val};

    // Low FRAC bits of the product are intentionally discarded by the >>FRAC.
    logic _unused_frac;
    assign _unused_frac = &{1'b0, prod[FRAC-1:0]};
endmodule
