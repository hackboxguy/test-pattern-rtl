// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 2 (video) — timing_source_mux (STUB body — M4)
// Selects the timing/coordinate source for the pattern core: local VTG vs
// captured stream (PRD §8.8). The mux itself is trivial; the AUTO control that
// drives sel_local lives in video_mode_mgr (runs on mgmt_clk, FR-AUTO-CLK).
module timing_source_mux #(
    parameter int HCOORD_W = 12,
    parameter int VCOORD_W = 12,
    parameter int FRAME_W  = 24
)(
    input  logic                sel_local,   // 1 = local VTG, 0 = captured
    // local (Mode A / fallback) source
    input  logic                l_de,
    input  logic                l_hsync,
    input  logic                l_vsync,
    input  logic                l_sof,
    input  logic                l_eol,
    input  logic [HCOORD_W-1:0] l_x0,
    input  logic [VCOORD_W-1:0] l_y,
    input  logic [FRAME_W-1:0]  l_frame,
    // captured (Mode B) source
    input  logic                c_de,
    input  logic                c_hsync,
    input  logic                c_vsync,
    input  logic                c_sof,
    input  logic                c_eol,
    input  logic [HCOORD_W-1:0] c_x0,
    input  logic [VCOORD_W-1:0] c_y,
    input  logic [FRAME_W-1:0]  c_frame,
    // selected output
    output logic                o_de,
    output logic                o_hsync,
    output logic                o_vsync,
    output logic                o_sof,
    output logic                o_eol,
    output logic [HCOORD_W-1:0] o_x0,
    output logic [VCOORD_W-1:0] o_y,
    output logic [FRAME_W-1:0]  o_frame
);
    assign o_de    = sel_local ? l_de    : c_de;
    assign o_hsync = sel_local ? l_hsync : c_hsync;
    assign o_vsync = sel_local ? l_vsync : c_vsync;
    assign o_sof   = sel_local ? l_sof   : c_sof;
    assign o_eol   = sel_local ? l_eol   : c_eol;
    assign o_x0    = sel_local ? l_x0    : c_x0;
    assign o_y     = sel_local ? l_y     : c_y;
    assign o_frame = sel_local ? l_frame : c_frame;
endmodule
