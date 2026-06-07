// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 1 (video) — video_source_core
//
// Free-running pattern source (Mode A): video_timing_gen + pattern_pixel_core +
// video_delay, producing an aligned Simple-Sync stream (PRD §7.1 Tier 1, §8.5).
// The VTG sideband is delayed by PATTERN_LATENCY so it lines up with the
// pattern core's registered rgb. Instantiate with a VMODE_* macro from
// video_modes.svh, e.g.:
//
//   video_source_core #(`VMODE_1280x720p60, .COLOR_W(8)) u_src (...);
module video_source_core #(
    // --- timing (from video_modes.svh) ---
    parameter int H_ACTIVE  = 640,
    parameter int H_FP      = 16,
    parameter int H_SYNC    = 96,
    parameter int H_BP      = 48,
    parameter int V_ACTIVE  = 480,
    parameter int V_FP      = 10,
    parameter int V_SYNC    = 2,
    parameter int V_BP      = 33,
    parameter bit HSYNC_POL = 1'b0,
    parameter bit VSYNC_POL = 1'b0,
    // --- formats / widths ---
    parameter int COLOR_W   = 8,
    parameter int HCOORD_W  = 12,
    parameter int VCOORD_W  = 12,
    parameter int FRAME_W   = 24,
    parameter int PATSEL_W  = 4,
    parameter int NPARAM    = 4,
    parameter int PARAM_W   = 32,
    // --- pattern tuning ---
    parameter int CHECKER_LOG2    = 4,
    parameter int GRID_PITCH_LOG2 = 5,
    parameter int GRID_LINE_W     = 1,
    parameter int RAMP_FRAC       = 12
)(
    input  logic                    clk,
    input  logic                    rst,
    // control (already in this clock domain; cfg CDC/commit added in M1 cfg work)
    input  logic                    pat_en,
    input  logic [PATSEL_W-1:0]     pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0] param,
    // aligned Simple-Sync output
    output logic                    de,
    output logic                    hsync,
    output logic                    vsync,
    output logic                    sof,
    output logic                    eol,
    output logic [HCOORD_W-1:0]     x0,
    output logic [VCOORD_W-1:0]     y,
    output logic [FRAME_W-1:0]      frame,
    output logic [3*COLOR_W-1:0]    rgb
);
    localparam int PAT_LAT = 1;  // MUST match pattern_pixel_core PATTERN_LATENCY

    // --- timing generator ---
    logic                de_v, hsync_v, vsync_v, sof_v, eol_v;
    logic [HCOORD_W-1:0] x0_v;
    logic [VCOORD_W-1:0] y_v;
    logic [FRAME_W-1:0]  frame_v;

    video_timing_gen #(
        .H_ACTIVE(H_ACTIVE), .H_FP(H_FP), .H_SYNC(H_SYNC), .H_BP(H_BP),
        .V_ACTIVE(V_ACTIVE), .V_FP(V_FP), .V_SYNC(V_SYNC), .V_BP(V_BP),
        .HSYNC_POL(HSYNC_POL), .VSYNC_POL(VSYNC_POL),
        .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W), .FRAME_W(FRAME_W)
    ) u_vtg (
        .clk(clk), .rst(rst),
        .de(de_v), .hsync(hsync_v), .vsync(vsync_v), .sof(sof_v), .eol(eol_v),
        .x0(x0_v), .y(y_v), .frame(frame_v)
    );

    // --- pattern core (latency PAT_LAT) ---
    pattern_pixel_core #(
        .COLOR_W(COLOR_W), .PIXELS_PER_CLOCK(1),
        .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W), .FRAME_W(FRAME_W),
        .PATSEL_W(PATSEL_W), .NPARAM(NPARAM), .PARAM_W(PARAM_W),
        .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE),
        .CHECKER_LOG2(CHECKER_LOG2), .GRID_PITCH_LOG2(GRID_PITCH_LOG2),
        .GRID_LINE_W(GRID_LINE_W), .RAMP_FRAC(RAMP_FRAC)
    ) u_core (
        .clk(clk), .rst(rst),
        .de(de_v), .de_mask(de_v),
        .x0(x0_v), .y(y_v), .frame(frame_v), .sof(sof_v), .eol(eol_v),
        .h_active(HCOORD_W'(H_ACTIVE)), .v_active(VCOORD_W'(V_ACTIVE)),
        .pat_en(pat_en), .pattern_sel(pattern_sel), .param(param),
        .rgb(rgb), .de_mask_out(core_de_mask)
    );
    logic core_de_mask;  // ppc=1: redundant with the delayed de below
    logic _unused_dm;
    assign _unused_dm = &{1'b0, core_de_mask};

    // --- align VTG sideband to the pattern latency ---
    localparam int SB_W = 5 + HCOORD_W + VCOORD_W + FRAME_W;
    logic [SB_W-1:0] sb_in, sb_out;
    assign sb_in = {de_v, hsync_v, vsync_v, sof_v, eol_v, x0_v, y_v, frame_v};

    video_delay #(.WIDTH(SB_W), .DEPTH(PAT_LAT)) u_sbdelay (
        .clk(clk), .rst(rst), .d(sb_in), .q(sb_out)
    );

    assign {de, hsync, vsync, sof, eol, x0, y, frame} = sb_out;
endmodule
