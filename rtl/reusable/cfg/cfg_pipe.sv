// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_pipe
//
// Full runtime-config path (PRD §8.6): control-domain shadow registers
// (cfg_regs) -> handshake CDC (cfg_cdc) -> pixel-domain atomic commit on sof
// (cfg_commit). Host writes {pat_en, pattern_sel, param} in ctrl_clk; the
// active config used by pattern_pixel_core updates atomically on a frame
// boundary in pix_clk. Drop-in between a control adapter and video_source_core.
module cfg_pipe #(
    parameter int PATSEL_W = 4,
    parameter int NPARAM   = 4,
    parameter int PARAM_W  = 32,
    parameter int FRAME_W  = 24
)(
    // control (host) domain
    input  logic                      ctrl_clk,
    input  logic                      ctrl_rst,
    input  logic [PATSEL_W-1:0]       w_pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0] w_param,
    input  logic                      w_pat_en,
    input  logic                      w_strobe,
    output logic                      ctrl_busy,
    // pixel domain
    input  logic                      pix_clk,
    input  logic                      pix_rst,
    input  logic                      sof,
    input  logic [FRAME_W-1:0]        frame,
    output logic [PATSEL_W-1:0]       active_pattern_sel,
    output logic [NPARAM*PARAM_W-1:0] active_param,
    output logic                      active_pat_en,
    output logic                      cfg_pending,
    output logic                      cfg_applied,
    output logic [FRAME_W-1:0]        applied_frame
);
    localparam int BUND_W = 1 + PATSEL_W + NPARAM*PARAM_W;

    logic [BUND_W-1:0] shadow, staged, active;
    logic              update, busy, staged_update;

    assign ctrl_busy = busy;

    cfg_regs #(.PATSEL_W(PATSEL_W), .NPARAM(NPARAM), .PARAM_W(PARAM_W)) u_regs (
        .clk(ctrl_clk), .rst(ctrl_rst),
        .w_pattern_sel(w_pattern_sel), .w_param(w_param), .w_pat_en(w_pat_en), .w_strobe(w_strobe),
        .busy(busy), .shadow(shadow), .update(update)
    );

    cfg_cdc #(.W(BUND_W)) u_cdc (
        .src_clk(ctrl_clk), .src_rst(ctrl_rst), .src_data(shadow), .src_update(update), .src_busy(busy),
        .dst_clk(pix_clk), .dst_rst(pix_rst), .dst_data(staged), .dst_update(staged_update)
    );

    cfg_commit #(.BUND_W(BUND_W), .FRAME_W(FRAME_W)) u_commit (
        .clk(pix_clk), .rst(pix_rst),
        .staged(staged), .staged_update(staged_update),
        .sof(sof), .frame(frame),
        .active(active), .cfg_pending(cfg_pending), .cfg_applied(cfg_applied), .applied_frame(applied_frame)
    );

    assign {active_pat_en, active_pattern_sel, active_param} = active;
endmodule
