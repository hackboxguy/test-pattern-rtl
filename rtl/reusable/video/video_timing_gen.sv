// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 1 (video) — video_timing_gen (STUB — implemented in M1)
// Mode A Video Timing Generator (PRD §8.4). M1 replaces this stub with the
// real VESA/CEA resolution-table-driven counters (hsync/vsync/de/x/y/frame +
// sof/eol), including standard_family/vic fields.
module video_timing_gen #(
    parameter int HCOORD_W = 12,
    parameter int VCOORD_W = 12,
    parameter int FRAME_W  = 24
)(
    input  logic                clk,
    input  logic                rst,
    output logic                de,
    output logic                hsync,
    output logic                vsync,
    output logic                sof,
    output logic                eol,
    output logic [HCOORD_W-1:0] x0,
    output logic [VCOORD_W-1:0] y,
    output logic [FRAME_W-1:0]  frame
);
    // STUB: outputs parked until M1.
    assign de    = 1'b0;
    assign hsync = 1'b0;
    assign vsync = 1'b0;
    assign sof   = 1'b0;
    assign eol   = 1'b0;
    assign x0    = '0;
    assign y     = '0;
    assign frame = '0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, clk, rst};
endmodule
