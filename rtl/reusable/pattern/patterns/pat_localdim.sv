// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern family — local-dimming benchmark patterns
//
// One sub-selected family (Codex PRD review v3) for testing local-dimming /
// miniLED / FALD displays: average-picture-level windows, zone contrast, black
// crush, subtitle haloing, and temporal response. All built from cheap
// coordinate comparators + the frame counter — no framebuffer, no division, and
// no extra multipliers (the normalized coordinates norm_x/norm_y are supplied by
// the core's existing ramp datapath).
//
//   sub : 0 WINDOW   centered ~1/4 x 1/4 white box on black  (APL / blooming)
//         1 WIN_MOVE same box sweeping horizontally           (dimming tracking)
//         2 CHK_ZONE coarse 8x8 zone checkerboard             (ANSI contrast)
//         3 NEARBLK  near-black vertical step wedge            (black crush)
//         4 SUBTITLE white blocks along the bottom            (subtitle halo)
//         5 FLASH    full-field black<->white every 32 frames (response time)
module pat_localdim #(
    parameter int COLOR_W  = 8,
    parameter int HCOORD_W = 12,
    parameter int VCOORD_W = 12,
    parameter int FRAME_W  = 24,
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480
)(
    input  logic                   clk,
    input  logic                   rst,      // active-high, synchronous
    input  logic [HCOORD_W-1:0]  x,
    input  logic [VCOORD_W-1:0]  y,
    input  logic [FRAME_W-1:0]   frame,
    input  logic [COLOR_W-1:0]   norm_x,   // x mapped to [0,2^COLOR_W) — reuses ramp_h
    input  logic [COLOR_W-1:0]   norm_y,   // y mapped to [0,2^COLOR_W) — reuses ramp_v
    input  logic [2:0]           sub,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [3*COLOR_W-1:0] WHITE = '1;
    localparam logic [3*COLOR_W-1:0] BLACK = '0;

    // ---- window geometry (compile-time, constant-folded) ----
    localparam int WW  = H_ACTIVE / 4;            // window 1/4 x 1/4 (~6% area)
    localparam int WH  = V_ACTIVE / 4;
    localparam int WX0 = (H_ACTIVE - WW) / 2;     // centered
    localparam int WY0 = (V_ACTIVE - WH) / 2;

    logic win;
    assign win = (x >= HCOORD_W'(WX0)) && (x < HCOORD_W'(WX0 + WW)) &&
                 (y >= VCOORD_W'(WY0)) && (y < VCOORD_W'(WY0 + WH));

    // ---- moving window: horizontal triangle sweep, vertically centered ----
    // Travel amplitude is the largest power of two that fits the span, so the
    // bounce is a mask+compare+subtract on the frame counter (no multiply/modulo).
    localparam int MTRX  = H_ACTIVE - WW;
    localparam int MAMP  = (1 << ($clog2(MTRX) - 1));
    localparam int MBASX = (MTRX - MAMP) / 2;
    localparam int MMASK = 2 * MAMP - 1;

    // MMASK < 2^HCOORD_W, so only the low HCOORD_W bits of the frame counter
    // matter — keep the whole triangle at coordinate width (no wide/unused bits).
    logic [HCOORD_W-1:0] mph, mtri, mwx0;
    assign mph  = frame[HCOORD_W-1:0] & HCOORD_W'(MMASK);
    assign mtri = (mph < HCOORD_W'(MAMP)) ? mph : (HCOORD_W'(MMASK) - mph);
    assign mwx0 = HCOORD_W'(MBASX) + mtri;

    logic mwin;
    assign mwin = (x >= mwx0) && (x < mwx0 + HCOORD_W'(WW)) &&
                  (y >= VCOORD_W'(WY0)) && (y < VCOORD_W'(WY0 + WH));

    // ---- coarse 8x8 zone checkerboard ----
    // bit [COLOR_W-3] of a normalized coord toggles every 1/8 of the span (it is the
    // LSB of the top-3-bit band index 0..7), so its x==y equality is an 8x8 checker.
    logic zone_chk;
    assign zone_chk = (norm_x[COLOR_W-3] == norm_y[COLOR_W-3]);

    // ---- near-black step wedge: 8 vertical bands of low code values ----
    logic [COLOR_W-1:0] nb_val;
    always_comb begin
        case (norm_x[COLOR_W-1 -: 3])
            3'd0:    nb_val = COLOR_W'(0);
            3'd1:    nb_val = COLOR_W'(1);
            3'd2:    nb_val = COLOR_W'(2);
            3'd3:    nb_val = COLOR_W'(4);
            3'd4:    nb_val = COLOR_W'(8);
            3'd5:    nb_val = COLOR_W'(16);
            3'd6:    nb_val = COLOR_W'(32);
            default: nb_val = COLOR_W'(64);
        endcase
    end

    // ---- subtitle: a row of three white blocks near the bottom ----
    localparam int SBY0 = (V_ACTIVE * 7) / 8;
    localparam int SBY1 = SBY0 + (V_ACTIVE / 16) + 1;     // +1 so it's visible at tiny geometries
    localparam int B1X0 = H_ACTIVE / 8,        B1X1 = B1X0 + H_ACTIVE / 6;
    localparam int B2X0 = (H_ACTIVE * 5) / 12, B2X1 = B2X0 + H_ACTIVE / 4;
    localparam int B3X0 = (H_ACTIVE * 3) / 4,  B3X1 = B3X0 + H_ACTIVE / 8;

    logic sub_on;
    assign sub_on = (y >= VCOORD_W'(SBY0)) && (y < VCOORD_W'(SBY1)) &&
                    (((x >= HCOORD_W'(B1X0)) && (x < HCOORD_W'(B1X1)))  ||
                     ((x >= HCOORD_W'(B2X0)) && (x < HCOORD_W'(B2X1)))  ||
                     ((x >= HCOORD_W'(B3X0)) && (x < HCOORD_W'(B3X1))));

    // ---- full-field flash: toggle every 32 frames ----
    logic flash;
    assign flash = frame[5];

    // motion/flash use only the low frame bits; sink the rest for lint.
    logic _unused_frame;
    assign _unused_frame = &{1'b0, frame[FRAME_W-1:HCOORD_W]};

    // ---- stage 1: register predicates before the final sub-pattern mux ----
    logic [2:0]         sub_q;
    logic               win_q, mwin_q, zone_chk_q, sub_on_q, flash_q;
    logic [COLOR_W-1:0] nb_val_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            sub_q      <= '0;
            win_q      <= 1'b0;
            mwin_q     <= 1'b0;
            zone_chk_q <= 1'b0;
            nb_val_q   <= '0;
            sub_on_q   <= 1'b0;
            flash_q    <= 1'b0;
        end else begin
            sub_q      <= sub;
            win_q      <= win;
            mwin_q     <= mwin;
            zone_chk_q <= zone_chk;
            nb_val_q   <= nb_val;
            sub_on_q   <= sub_on;
            flash_q    <= flash;
        end
    end

    // ---- sub-pattern mux ----
    always_comb begin
        case (sub_q)
            3'd0:    rgb = win_q      ? WHITE : BLACK;
            3'd1:    rgb = mwin_q     ? WHITE : BLACK;
            3'd2:    rgb = zone_chk_q ? WHITE : BLACK;
            3'd3:    rgb = {nb_val_q, nb_val_q, nb_val_q};
            3'd4:    rgb = sub_on_q   ? WHITE : BLACK;
            3'd5:    rgb = flash_q    ? WHITE : BLACK;
            default: rgb = BLACK;
        endcase
    end
endmodule
