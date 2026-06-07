// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 1 (video) — video_timing_gen
//
// Mode A Video Timing Generator (PRD §8.4). Free-running H/V counters drive a
// registered Simple-Sync sideband bundle: de, hsync, vsync, sof, eol, x0, y,
// frame. All outputs are registered from the same counter state, so they are
// mutually aligned. Active region is at the start of each line/frame
// (active, front porch, sync, back porch). Timings come from video_modes.svh.
module video_timing_gen #(
    // Horizontal timing (pixels)
    parameter int H_ACTIVE  = 640,
    parameter int H_FP      = 16,
    parameter int H_SYNC    = 96,
    parameter int H_BP      = 48,
    // Vertical timing (lines)
    parameter int V_ACTIVE  = 480,
    parameter int V_FP      = 10,
    parameter int V_SYNC    = 2,
    parameter int V_BP      = 33,
    // Sync polarity: 1 = active-high sync pulse
    parameter bit HSYNC_POL = 1'b0,
    parameter bit VSYNC_POL = 1'b0,
    // Output coordinate / frame widths
    parameter int HCOORD_W  = 12,
    parameter int VCOORD_W  = 12,
    parameter int FRAME_W   = 24
)(
    input  logic                clk,
    input  logic                rst,        // active-high, synchronous
    output logic                de,
    output logic                hsync,
    output logic                vsync,
    output logic                sof,
    output logic                eol,
    output logic [HCOORD_W-1:0] x0,
    output logic [VCOORD_W-1:0] y,
    output logic [FRAME_W-1:0]  frame
);
    localparam int H_TOTAL     = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam int V_TOTAL     = V_ACTIVE + V_FP + V_SYNC + V_BP;
    localparam int HSYNC_START = H_ACTIVE + H_FP;
    localparam int HSYNC_END   = H_ACTIVE + H_FP + H_SYNC;
    localparam int VSYNC_START = V_ACTIVE + V_FP;
    localparam int VSYNC_END   = V_ACTIVE + V_FP + V_SYNC;
    localparam int HCW         = $clog2(H_TOTAL);
    localparam int VCW         = $clog2(V_TOTAL);

    logic [HCW-1:0] hcnt;
    logic [VCW-1:0] vcnt;

    // Free-running pixel/line counters.
    always_ff @(posedge clk) begin
        if (rst) begin
            hcnt <= '0;
            vcnt <= '0;
        end else if (hcnt == HCW'(H_TOTAL-1)) begin
            hcnt <= '0;
            vcnt <= (vcnt == VCW'(V_TOTAL-1)) ? '0 : (vcnt + VCW'(1));
        end else begin
            hcnt <= hcnt + HCW'(1);
        end
    end

    // Combinational decode of the current counter state.
    logic active_h, active_v;
    logic de_c, hs_c, vs_c, sof_c, eol_c, eof_c;
    assign active_h = (hcnt < HCW'(H_ACTIVE));
    assign active_v = (vcnt < VCW'(V_ACTIVE));
    assign de_c     = active_h & active_v;
    assign hs_c     = (hcnt >= HCW'(HSYNC_START) && hcnt < HCW'(HSYNC_END)) ? HSYNC_POL : ~HSYNC_POL;
    assign vs_c     = (vcnt >= VCW'(VSYNC_START) && vcnt < VCW'(VSYNC_END)) ? VSYNC_POL : ~VSYNC_POL;
    assign sof_c    = (hcnt == '0) && (vcnt == '0);                 // first active pixel
    assign eol_c    = (hcnt == HCW'(H_ACTIVE-1)) && active_v;       // last active pixel of line
    assign eof_c    = (hcnt == HCW'(H_TOTAL-1)) && (vcnt == VCW'(V_TOTAL-1));

    // Registered outputs — all aligned to the same counter state.
    always_ff @(posedge clk) begin
        if (rst) begin
            de    <= 1'b0;
            hsync <= ~HSYNC_POL;
            vsync <= ~VSYNC_POL;
            sof   <= 1'b0;
            eol   <= 1'b0;
            x0    <= '0;
            y     <= '0;
            frame <= '0;
        end else begin
            de    <= de_c;
            hsync <= hs_c;
            vsync <= vs_c;
            sof   <= sof_c;
            eol   <= eol_c;
            x0    <= active_h ? HCOORD_W'(hcnt) : '0;
            y     <= active_v ? VCOORD_W'(vcnt) : '0;
            if (eof_c) frame <= frame + FRAME_W'(1);
        end
    end
endmodule
