// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 — pattern_pixel_core
//
// Portable, vendor-neutral pattern engine: (x0, y, frame, config) -> rgb.
// PRD §8.1 / §10.1.
//
// M0 SEED: solid-colour patterns only (IDs 0..4). The full v1 set
// (gray / color-bars / ramps / checker / grid) and any pipelining land in M1.
//
// Contract (FR-CORE-4 / FR-SB-5): fixed PATTERN_LATENCY; this module emits
// rgb / de_mask_out ONLY. Sideband alignment (hsync/vsync/sof/eol/x/y/frame)
// is owned by the Tier 1/2 wrapper via video_delay — NOT here.
`include "pattern_ids.svh"

module pattern_pixel_core #(
    parameter int COLOR_W          = 8,    // bits per channel (RGB888 -> 8)
    parameter int PIXELS_PER_CLOCK = 1,    // MUST be 1 in v1 (ABI defined for >1)
    parameter int HCOORD_W         = 12,
    parameter int VCOORD_W         = 12,
    parameter int FRAME_W          = 24,
    parameter int PATSEL_W         = 4,
    parameter int NPARAM           = 4,
    parameter int PARAM_W          = 32
)(
    input  logic                                  clk,
    input  logic                                  rst,         // active-high, synchronous
    // timing / coordinate stream (from VTG or capture); lane 0 = x0
    input  logic                                  de,
    input  logic [PIXELS_PER_CLOCK-1:0]           de_mask,
    input  logic [HCOORD_W-1:0]                   x0,
    input  logic [VCOORD_W-1:0]                   y,
    input  logic [FRAME_W-1:0]                     frame,
    input  logic                                  sof,
    input  logic                                  eol,
    // active geometry (constant in Mode A, measured in Mode B)
    input  logic [HCOORD_W-1:0]                   h_active,
    input  logic [VCOORD_W-1:0]                   v_active,
    // active_config (already CDC'd and frame-latched upstream by cfg_cdc)
    input  logic                                  pat_en,
    input  logic [PATSEL_W-1:0]                   pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0]             param,
    // pixel output ONLY (fixed PATTERN_LATENCY); sideband alignment in Tier 1/2
    output logic [PIXELS_PER_CLOCK*3*COLOR_W-1:0] rgb,         // {R,G,B} MSB->LSB per lane
    output logic [PIXELS_PER_CLOCK-1:0]           de_mask_out
);

    // Fixed pipeline latency of this core (PRD FR-CORE-4). Exposed for the
    // Tier 1/2 video_delay depth. Kept as a localparam contract.
    localparam int PATTERN_LATENCY = 1;
    localparam int LATENCY_MARK    = PATTERN_LATENCY; // referenced below to keep linters quiet

    // v1 restricts to one pixel per clock (PRD §8.1, FR-CORE-3).
    if (PIXELS_PER_CLOCK != 1) begin : g_ppc_guard
        $error("pattern_pixel_core: PIXELS_PER_CLOCK > 1 is not supported until M5");
    end

    localparam logic [COLOR_W-1:0] CH_LO = '0;
    localparam logic [COLOR_W-1:0] CH_HI = '1;

    // Combinational colour for one pixel: {R, G, B}, MSB->LSB (PRD §8.1).
    logic [3*COLOR_W-1:0] pix;
    always_comb begin
        unique case (pattern_sel)
            PATSEL_W'(`PAT_WHITE): pix = {CH_HI, CH_HI, CH_HI};
            PATSEL_W'(`PAT_RED):   pix = {CH_HI, CH_LO, CH_LO};
            PATSEL_W'(`PAT_GREEN): pix = {CH_LO, CH_HI, CH_LO};
            PATSEL_W'(`PAT_BLUE):  pix = {CH_LO, CH_LO, CH_HI};
            // PAT_BLACK and any not-yet-implemented / disabled ID -> black (FR-ABI-2)
            default:               pix = {CH_LO, CH_LO, CH_LO};
        endcase
        if (!pat_en) pix = '0;
    end

    // Registered output -> PATTERN_LATENCY = 1.
    always_ff @(posedge clk) begin
        if (rst) begin
            rgb         <= '0;
            de_mask_out <= '0;
        end else begin
            rgb         <= pix;
            de_mask_out <= de_mask;
        end
    end

    // Inputs reserved for M1+ patterns (coordinates, sideband, geometry, params).
    // Named '_unused' so Verilator treats the consumption as intentional.
    logic _unused_ok;
    assign _unused_ok = &{1'b0, de, sof, eol, x0, y, frame,
                          h_active, v_active, param, LATENCY_MARK[0]};

endmodule
