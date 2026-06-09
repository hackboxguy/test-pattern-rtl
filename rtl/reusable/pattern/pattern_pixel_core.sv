// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 — pattern_pixel_core
//
// Portable, vendor-neutral pattern engine: (x0, y, config) -> rgb. PRD §8.1/§10.1.
//
// v1 pattern set (PRD §8.2): solids + grays (inline constants), color bars,
// horizontal/vertical ramps, checker, 1-pixel checker, and grid — instantiated
// from rtl/reusable/pattern/patterns/ and muxed by the stable pattern IDs in
// pattern_ids.svh. Disabled / not-yet-implemented IDs return black (FR-ABI-2).
//
// Contract (FR-CORE-4): fixed PATTERN_LATENCY (= 4); emits rgb / de_mask_out
// ONLY. Sideband alignment is owned by the Tier 1/2 wrapper (video_source_core).
//
// M1 scope: patterns use the compile-time H_ACTIVE/V_ACTIVE parameters (Mode A),
// so all geometry math is constant-folded and division/modulo-free (FR-CORE-6).
// The runtime h_active/v_active inputs are honoured from M4 (Mode B).
`include "pattern_ids.svh"

module pattern_pixel_core #(
    parameter int COLOR_W          = 8,    // bits per channel (RGB888 -> 8)
    parameter int PIXELS_PER_CLOCK = 1,    // MUST be 1 in v1 (ABI defined for >1)
    parameter int HCOORD_W         = 12,
    parameter int VCOORD_W         = 12,
    parameter int FRAME_W          = 24,
    parameter int PATSEL_W         = 5,    // 5 bits addresses the 32-pattern set
    parameter int NPARAM           = 4,
    parameter int PARAM_W          = 32,
    // pattern geometry / tuning (Mode A, compile-time)
    parameter int H_ACTIVE         = 640,
    parameter int V_ACTIVE         = 480,
    parameter int CHECKER_LOG2     = 4,    // checker block = 2^4 = 16 px
    parameter int GRID_PITCH_LOG2  = 5,    // grid pitch  = 2^5 = 32 px
    parameter int GRID_LINE_W      = 1,
    parameter int RAMP_FRAC        = 12,
    parameter int STAIR_BITS       = 4,    // grayscale staircase: 2^4 = 16 steps
    parameter int LD1D_ZONES       = 48    // 1D local-dimming: LED/zone count across width
)(
    input  logic                                  clk,
    input  logic                                  rst,         // active-high, synchronous
    input  logic                                  de,
    input  logic [PIXELS_PER_CLOCK-1:0]           de_mask,
    input  logic [HCOORD_W-1:0]                   x0,
    input  logic [VCOORD_W-1:0]                   y,
    input  logic [FRAME_W-1:0]                     frame,
    input  logic                                  sof,
    input  logic                                  eol,
    input  logic [HCOORD_W-1:0]                   h_active,
    input  logic [VCOORD_W-1:0]                   v_active,
    input  logic                                  pat_en,
    input  logic [PATSEL_W-1:0]                   pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0]             param,
    output logic [PIXELS_PER_CLOCK*3*COLOR_W-1:0] rgb,         // {R,G,B} MSB->LSB per lane
    output logic [PIXELS_PER_CLOCK-1:0]           de_mask_out
);

    localparam int PATTERN_LATENCY = 4;  // fixed Tier 0 latency (PRD FR-CORE-4)

    // v1 restricts to one pixel per clock (PRD §8.1, FR-CORE-3).
    if (PIXELS_PER_CLOCK != 1) begin : g_ppc_guard
        $error("pattern_pixel_core: PIXELS_PER_CLOCK > 1 is not supported until M5");
    end

    localparam logic [COLOR_W-1:0] CH_LO = '0;
    localparam logic [COLOR_W-1:0] CH_HI = '1;
    // Gray levels ~25/50/75% (0x3F / 0x7F / 0xBF at 8-bit).
    localparam logic [COLOR_W-1:0] G25 = CH_HI >> 2;
    localparam logic [COLOR_W-1:0] G50 = CH_HI >> 1;
    localparam logic [COLOR_W-1:0] G75 = CH_HI - (CH_HI >> 2);

    // ---- stage 1: align non-ramp inputs with the registered ramp multiply ----
    logic                                  de_s1;
    logic [PIXELS_PER_CLOCK-1:0]           de_mask_s1;
    logic [HCOORD_W-1:0]                   x0_s1;
    logic [VCOORD_W-1:0]                   y_s1;
    logic [FRAME_W-1:0]                    frame_s1;
    logic                                  pat_en_s1;
    logic [PATSEL_W-1:0]                   pattern_sel_s1;

    always_ff @(posedge clk) begin
        if (rst) begin
            de_s1          <= 1'b0;
            de_mask_s1     <= '0;
            x0_s1          <= '0;
            y_s1           <= '0;
            frame_s1       <= '0;
            pat_en_s1      <= 1'b0;
            pattern_sel_s1 <= '0;
        end else begin
            de_s1          <= de;
            de_mask_s1     <= de_mask;
            x0_s1          <= x0;
            y_s1           <= y;
            frame_s1       <= frame;
            pat_en_s1      <= pat_en;
            pattern_sel_s1 <= pattern_sel;
        end
    end

    // ---- computational patterns ----
    logic [3*COLOR_W-1:0] bars_rgb, ramph_rgb, rampv_rgb, checker_rgb, checker1_rgb, grid_rgb;

    pat_color_bars #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .H_ACTIVE(H_ACTIVE))
        u_bars (.x(x0_s1), .rgb(bars_rgb));

    pat_ramp #(.COLOR_W(COLOR_W), .COORD_W(HCOORD_W), .DIM(H_ACTIVE), .FRAC(RAMP_FRAC))
        u_ramp_h (.clk(clk), .rst(rst), .coord(x0), .rgb(ramph_rgb));

    pat_ramp #(.COLOR_W(COLOR_W), .COORD_W(VCOORD_W), .DIM(V_ACTIVE), .FRAC(RAMP_FRAC))
        u_ramp_v (.clk(clk), .rst(rst), .coord(y), .rgb(rampv_rgb));

    pat_checker #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W), .BLOCK_LOG2(CHECKER_LOG2))
        u_checker (.x(x0_s1), .y(y_s1), .rgb(checker_rgb));

    pat_checker #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W), .BLOCK_LOG2(0))
        u_checker1 (.x(x0_s1), .y(y_s1), .rgb(checker1_rgb));

    pat_grid #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W),
               .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE),
               .PITCH_LOG2(GRID_PITCH_LOG2), .LINE_W(GRID_LINE_W))
        u_grid (.x(x0_s1), .y(y_s1), .rgb(grid_rgb));

    // ---- local-dimming benchmark family (PAT_LD_*; sub = id - PAT_LD_WINDOW) ----
    // Reuses the ramp_h/ramp_v normalized values (no extra multipliers) and the
    // frame counter for motion/temporal patterns.
    logic [3*COLOR_W-1:0] ld_rgb;
    logic [2:0]           ld_sub;
    assign ld_sub = 3'(pattern_sel_s1 - PATSEL_W'(`PAT_LD_WINDOW));
    pat_localdim #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W),
                   .FRAME_W(FRAME_W), .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE))
        u_localdim (.clk(clk), .rst(rst), .x(x0_s1), .y(y_s1), .frame(frame_s1),
                    .norm_x(ramph_rgb[COLOR_W-1:0]), .norm_y(rampv_rgb[COLOR_W-1:0]),
                    .sub(ld_sub), .rgb(ld_rgb));

    // ---- 1D edge-bar local-dimming family (PAT_LD1D_*; sub = id - PAT_LD1D_COLUMN) ----
    logic [3*COLOR_W-1:0] ld1d_rgb;
    logic [2:0]           ld1d_sub;
    assign ld1d_sub = 3'(pattern_sel - PATSEL_W'(`PAT_LD1D_COLUMN));
    pat_localdim_1d #(.COLOR_W(COLOR_W), .HCOORD_W(HCOORD_W), .VCOORD_W(VCOORD_W),
                      .FRAME_W(FRAME_W), .H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE),
                      .ZONES(LD1D_ZONES))
        u_localdim_1d (.clk(clk), .rst(rst), .x(x0), .y(y), .frame(frame),
                       .sub(ld1d_sub), .rgb(ld1d_rgb));

    // ---- stage 2: register pattern candidates before the final mux ----
    logic                                  de_s2;
    logic [PIXELS_PER_CLOCK-1:0]           de_mask_s2;
    logic                                  pat_en_s2;
    logic [PATSEL_W-1:0]                   pattern_sel_s2;
    logic [3*COLOR_W-1:0]                  bars_rgb_s2, ramph_rgb_s2, rampv_rgb_s2;
    logic [3*COLOR_W-1:0]                  checker_rgb_s2, checker1_rgb_s2, grid_rgb_s2;

    always_ff @(posedge clk) begin
        if (rst) begin
            de_s2          <= 1'b0;
            de_mask_s2     <= '0;
            pat_en_s2      <= 1'b0;
            pattern_sel_s2 <= '0;
            bars_rgb_s2    <= '0;
            ramph_rgb_s2   <= '0;
            rampv_rgb_s2   <= '0;
            checker_rgb_s2 <= '0;
            checker1_rgb_s2 <= '0;
            grid_rgb_s2    <= '0;
        end else begin
            de_s2          <= de_s1;
            de_mask_s2     <= de_mask_s1;
            pat_en_s2      <= pat_en_s1;
            pattern_sel_s2 <= pattern_sel_s1;
            bars_rgb_s2    <= bars_rgb;
            ramph_rgb_s2   <= ramph_rgb;
            rampv_rgb_s2   <= rampv_rgb;
            checker_rgb_s2 <= checker_rgb;
            checker1_rgb_s2 <= checker1_rgb;
            grid_rgb_s2    <= grid_rgb;
        end
    end

    // ---- stage 3: align the internally pipelined local-dimming outputs ----
    logic                                  de_s3;
    logic [PIXELS_PER_CLOCK-1:0]           de_mask_s3;
    logic                                  pat_en_s3;
    logic [PATSEL_W-1:0]                   pattern_sel_s3;
    logic [3*COLOR_W-1:0]                  bars_rgb_s3, ramph_rgb_s3, rampv_rgb_s3;
    logic [3*COLOR_W-1:0]                  checker_rgb_s3, checker1_rgb_s3, grid_rgb_s3;
    logic [3*COLOR_W-1:0]                  ld_rgb_s3, ld1d_rgb_s3;

    always_ff @(posedge clk) begin
        if (rst) begin
            de_s3           <= 1'b0;
            de_mask_s3      <= '0;
            pat_en_s3       <= 1'b0;
            pattern_sel_s3  <= '0;
            bars_rgb_s3     <= '0;
            ramph_rgb_s3    <= '0;
            rampv_rgb_s3    <= '0;
            checker_rgb_s3  <= '0;
            checker1_rgb_s3 <= '0;
            grid_rgb_s3     <= '0;
            ld_rgb_s3       <= '0;
            ld1d_rgb_s3     <= '0;
        end else begin
            de_s3           <= de_s2;
            de_mask_s3      <= de_mask_s2;
            pat_en_s3       <= pat_en_s2;
            pattern_sel_s3  <= pattern_sel_s2;
            bars_rgb_s3     <= bars_rgb_s2;
            ramph_rgb_s3    <= ramph_rgb_s2;
            rampv_rgb_s3    <= rampv_rgb_s2;
            checker_rgb_s3  <= checker_rgb_s2;
            checker1_rgb_s3 <= checker1_rgb_s2;
            grid_rgb_s3     <= grid_rgb_s2;
            ld_rgb_s3       <= ld_rgb;
            ld1d_rgb_s3     <= ld1d_rgb;
        end
    end

    // ---- grayscale staircase: quantize the horizontal ramp value to 2^STAIR_BITS
    //      steps (top STAIR_BITS bits replicated). Reuses the ramp_h datapath. ----
    logic [COLOR_W-1:0]   ramp_val;   // horizontal ramp value (B channel of ramp_h)
    logic [COLOR_W-1:0]   stair_val;
    logic [3*COLOR_W-1:0] stair_rgb;
    assign ramp_val  = ramph_rgb_s3[COLOR_W-1:0];
    assign stair_val = {(COLOR_W/STAIR_BITS){ramph_rgb_s3[COLOR_W-1 -: STAIR_BITS]}};
    assign stair_rgb = {stair_val, stair_val, stair_val};

    // ---- mux by stable pattern ID ----
    logic [3*COLOR_W-1:0] pix;
    always_comb begin
        unique case (pattern_sel_s3)
            PATSEL_W'(`PAT_WHITE):       pix = {CH_HI, CH_HI, CH_HI};
            PATSEL_W'(`PAT_RED):         pix = {CH_HI, CH_LO, CH_LO};
            PATSEL_W'(`PAT_GREEN):       pix = {CH_LO, CH_HI, CH_LO};
            PATSEL_W'(`PAT_BLUE):        pix = {CH_LO, CH_LO, CH_HI};
            PATSEL_W'(`PAT_GRAY25):      pix = {G25, G25, G25};
            PATSEL_W'(`PAT_GRAY50):      pix = {G50, G50, G50};
            PATSEL_W'(`PAT_GRAY75):      pix = {G75, G75, G75};
            PATSEL_W'(`PAT_COLOR_BARS):  pix = bars_rgb_s3;
            PATSEL_W'(`PAT_RAMP_H):      pix = ramph_rgb_s3;
            PATSEL_W'(`PAT_RAMP_V):      pix = rampv_rgb_s3;
            PATSEL_W'(`PAT_CHECKER):     pix = checker_rgb_s3;
            PATSEL_W'(`PAT_CHECKER_1PX): pix = checker1_rgb_s3;
            PATSEL_W'(`PAT_GRID):        pix = grid_rgb_s3;
            PATSEL_W'(`PAT_STAIRCASE):   pix = stair_rgb;
            PATSEL_W'(`PAT_RAMP_R):      pix = {ramp_val, CH_LO,    CH_LO};    // red-only
            PATSEL_W'(`PAT_RAMP_G):      pix = {CH_LO,    ramp_val, CH_LO};    // green-only
            PATSEL_W'(`PAT_RAMP_B):      pix = {CH_LO,    CH_LO,    ramp_val}; // blue-only
            PATSEL_W'(`PAT_LD_WINDOW),
            PATSEL_W'(`PAT_LD_WIN_MOVE),
            PATSEL_W'(`PAT_LD_CHECKER_ZONE),
            PATSEL_W'(`PAT_LD_NEARBLACK),
            PATSEL_W'(`PAT_LD_SUBTITLE),
            PATSEL_W'(`PAT_LD_FLASH):    pix = ld_rgb_s3;   // 2D local-dimming family
            PATSEL_W'(`PAT_LD1D_COLUMN),
            PATSEL_W'(`PAT_LD1D_SWEEP),
            PATSEL_W'(`PAT_LD1D_YWIN),
            PATSEL_W'(`PAT_LD1D_ALTZONES),
            PATSEL_W'(`PAT_LD1D_HBAND),
            PATSEL_W'(`PAT_LD1D_SUBTITLE),
            PATSEL_W'(`PAT_LD1D_FLASH),
            PATSEL_W'(`PAT_LD1D_DUAL):   pix = ld1d_rgb_s3; // 1D edge-bar local-dimming family
            default:                     pix = {CH_LO, CH_LO, CH_LO}; // PAT_BLACK + disabled IDs
        endcase
        // Blanking pixels are black (FR-SB-3); disabled core is black.
        if (!pat_en_s3 || !de_s3) pix = '0;
    end

    // Registered output -> PATTERN_LATENCY = 4.
    always_ff @(posedge clk) begin
        if (rst) begin
            rgb         <= '0;
            de_mask_out <= '0;
        end else begin
            rgb         <= pix;
            de_mask_out <= de_mask_s3;
        end
    end

    // Reserved for M1+ / Mode B (runtime geometry, params).
    logic _unused_ok;
    assign _unused_ok = &{1'b0, sof, eol, h_active, v_active, param,
                          PATTERN_LATENCY[0]};

endmodule
