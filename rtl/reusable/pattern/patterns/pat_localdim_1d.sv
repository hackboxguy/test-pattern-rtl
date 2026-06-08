// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern family — 1D (edge-bar) local-dimming patterns
//
// For displays whose backlight is a 1D bar of independently-controlled LEDs along
// the bottom (or top) edge -> the dimming zones are VERTICAL COLUMNS across the
// screen width (Codex PRD review v4). `ZONES` columns span H_ACTIVE; the zone
// index of a pixel is derived from the ramp's normalized x (norm_x) with one
// small constant multiply -- no runtime divide, no per-zone ROM, no framebuffer.
// ZONES is a parameter (= the panel's LED count, e.g. 40 / 47 / 48).
//
//   sub : 0 COLUMN    one centre-zone full-height column        (zone mapping)
//         1 SWEEP     one-zone column sweeping left->right       (zone tracking)
//         2 YWIN      top/mid/bottom windows in the centre zone  (light-guide reach)
//         3 ALTZONES  even zones white / odd black              (zone separation)
//         4 HBAND     full-width top/mid/bottom bands           (vertical uniformity)
//         5 SUBTITLE  white blocks near the bottom edge         (bottom-edge bloom)
//         6 FLASH     centre-zone column on/off every 32 frames (zone response)
//         7 DUAL      two columns (1/4 and 3/4 zones)           (independent control)
module pat_localdim_1d #(
    parameter int COLOR_W  = 8,
    parameter int HCOORD_W = 12,
    parameter int VCOORD_W = 12,
    parameter int FRAME_W  = 24,
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int ZONES    = 48          // LED count (vertical column zones across width)
)(
    input  logic [HCOORD_W-1:0]  x,
    input  logic [VCOORD_W-1:0]  y,
    input  logic [FRAME_W-1:0]   frame,
    input  logic [COLOR_W-1:0]   norm_x,  // x mapped to [0,2^COLOR_W) — reuses ramp_h
    input  logic [2:0]           sub,
    output logic [3*COLOR_W-1:0] rgb
);
    localparam logic [3*COLOR_W-1:0] WHITE = '1;
    localparam logic [3*COLOR_W-1:0] BLACK = '0;
    localparam int ZW = $clog2(ZONES + 1);   // bits to hold a zone value/index (0..ZONES)

    // ---- per-pixel zone index: floor(norm_x * ZONES / 2^COLOR_W), clamped ----
    logic [COLOR_W+ZW-1:0] zi_prod;
    logic [ZW-1:0]         zi_q, zone_idx;
    assign zi_prod  = norm_x * (COLOR_W+ZW)'(ZONES);
    assign zi_q     = zi_prod[COLOR_W+ZW-1:COLOR_W];
    assign zone_idx = (zi_q >= ZW'(ZONES)) ? ZW'(ZONES-1) : zi_q;

    localparam int ZC  = ZONES / 2;        // centre zone
    localparam int ZQ1 = ZONES / 4;        // quarter / three-quarter zones (dual)
    localparam int ZQ3 = (3 * ZONES) / 4;

    // ---- smooth sweep: a one-zone-wide column glides L->R by pixels and wraps
    //      (scol = floor(frame[7:0]*STRX/256) — ~one zone-width every few frames). ----
    localparam int COLW = (H_ACTIVE / ZONES < 1) ? 1 : H_ACTIVE / ZONES;  // one zone wide
    localparam int STRX = (H_ACTIVE - COLW < 1) ? 1 : H_ACTIVE - COLW;    // travel span
    logic [8+HCOORD_W-1:0] sprod;
    logic [HCOORD_W-1:0]   scol;
    logic                  sweep_on;
    assign sprod    = frame[7:0] * (8+HCOORD_W)'(STRX);
    assign scol     = sprod[8+HCOORD_W-1:8];
    assign sweep_on = (x >= scol) && (x < scol + HCOORD_W'(COLW));

    // ---- vertical windows / bands (compile-time y ranges) ----
    localparam int YW_H = V_ACTIVE / 8;                 // YWIN window height
    localparam int YW_T = V_ACTIVE / 16;
    localparam int YW_M = (V_ACTIVE - YW_H) / 2;
    localparam int YW_B = V_ACTIVE - YW_H - V_ACTIVE / 16;
    logic in_ywin_y;
    assign in_ywin_y = ((y >= VCOORD_W'(YW_T)) && (y < VCOORD_W'(YW_T + YW_H))) ||
                       ((y >= VCOORD_W'(YW_M)) && (y < VCOORD_W'(YW_M + YW_H))) ||
                       ((y >= VCOORD_W'(YW_B)) && (y < VCOORD_W'(YW_B + YW_H)));

    localparam int HB_H = V_ACTIVE / 12;                // HBAND band height
    localparam int HB_T = V_ACTIVE / 8;
    localparam int HB_M = (V_ACTIVE - HB_H) / 2;
    localparam int HB_B = V_ACTIVE - HB_H - V_ACTIVE / 8;
    logic in_hband;
    assign in_hband = ((y >= VCOORD_W'(HB_T)) && (y < VCOORD_W'(HB_T + HB_H))) ||
                      ((y >= VCOORD_W'(HB_M)) && (y < VCOORD_W'(HB_M + HB_H))) ||
                      ((y >= VCOORD_W'(HB_B)) && (y < VCOORD_W'(HB_B + HB_H)));

    // ---- bottom subtitle blocks (closest to a bottom-edge LED bar) ----
    localparam int SBY0 = (V_ACTIVE * 7) / 8;
    localparam int SBY1 = SBY0 + (V_ACTIVE / 16) + 1;
    localparam int SB1L = H_ACTIVE / 8,        SB1R = SB1L + H_ACTIVE / 6;
    localparam int SB2L = (H_ACTIVE * 5) / 12, SB2R = SB2L + H_ACTIVE / 4;
    localparam int SB3L = (H_ACTIVE * 3) / 4,  SB3R = SB3L + H_ACTIVE / 8;
    logic in_subt;
    assign in_subt = (y >= VCOORD_W'(SBY0)) && (y < VCOORD_W'(SBY1)) &&
                     (((x >= HCOORD_W'(SB1L)) && (x < HCOORD_W'(SB1R))) ||
                      ((x >= HCOORD_W'(SB2L)) && (x < HCOORD_W'(SB2R))) ||
                      ((x >= HCOORD_W'(SB3L)) && (x < HCOORD_W'(SB3R))));

    // ---- sub-pattern mux ----
    always_comb begin
        case (sub)
            3'd0:    rgb = (zone_idx == ZW'(ZC))                        ? WHITE : BLACK; // COLUMN
            3'd1:    rgb = sweep_on                                     ? WHITE : BLACK; // SWEEP (smooth)
            3'd2:    rgb = ((zone_idx == ZW'(ZC)) && in_ywin_y)         ? WHITE : BLACK; // YWIN
            3'd3:    rgb = zone_idx[0]                                  ? BLACK : WHITE; // ALTZONES (even white)
            3'd4:    rgb = in_hband                                     ? WHITE : BLACK; // HBAND
            3'd5:    rgb = in_subt                                      ? WHITE : BLACK; // SUBTITLE
            3'd6:    rgb = ((zone_idx == ZW'(ZC)) && frame[5])          ? WHITE : BLACK; // FLASH
            default: rgb = ((zone_idx == ZW'(ZQ1)) || (zone_idx == ZW'(ZQ3))) ? WHITE : BLACK; // DUAL
        endcase
    end

    // unused for lint: high frame bits, and the fractional (low) product bits.
    logic _unused;
    assign _unused = &{1'b0, frame[FRAME_W-1:8], zi_prod[COLOR_W-1:0], sprod[7:0]};
endmodule
