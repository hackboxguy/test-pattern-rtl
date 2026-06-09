// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 pattern family — 1D (edge-bar) local-dimming patterns
//
// For displays whose backlight is a 1D bar of independently-controlled LEDs along
// the bottom (or top) edge -> the dimming zones are VERTICAL COLUMNS across the
// screen width (Codex PRD review v4). `ZONES` columns span H_ACTIVE; the zone
// index of a pixel is floor(x*ZONES/H_ACTIVE), computed with ONE constant multiply
// by a fixed-point reciprocal -> sub-pixel-exact zone boundaries (no runtime
// divide, no per-zone ROM, no framebuffer). The smooth sweep uses a second small
// constant multiply (frame*STRX). ZONES = the panel's LED count (e.g. 40/47/48).
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
    input  logic                   clk,
    input  logic                   rst,    // active-high, synchronous
    input  logic [HCOORD_W-1:0]  x,
    input  logic [VCOORD_W-1:0]  y,
    input  logic [FRAME_W-1:0]   frame,
    input  logic [2:0]           sub,
    output logic [3*COLOR_W-1:0] rgb
);
    if (ZONES < 1) begin : g_bad_zones
        $error("pat_localdim_1d: ZONES must be >= 1");
    end

    localparam logic [3*COLOR_W-1:0] WHITE = '1;
    localparam logic [3*COLOR_W-1:0] BLACK = '0;

    // ---- per-pixel zone index = floor(x * ZONES / H_ACTIVE), via a fixed-point
    //      reciprocal: one constant multiply, sub-pixel-exact boundaries. ----
    localparam int ZFRAC    = 12;
    localparam int INV_ZONE = (ZONES * (1 << ZFRAC) + (H_ACTIVE / 2)) / H_ACTIVE; // round(ZONES*2^ZFRAC/H)
    localparam int IZW      = $clog2(INV_ZONE + 1);
    localparam int PW       = HCOORD_W + IZW;
    localparam int ZW       = $clog2(ZONES + 1);   // bits to hold 0..ZONES
    logic [PW-1:0]       zi_prod;
    logic [PW-ZFRAC-1:0] zi_q;
    logic [PW-ZFRAC-1:0] zi_q_reg;
    logic [ZW-1:0]       zone_idx;
    assign zi_prod  = x * IZW'(INV_ZONE);
    assign zi_q     = zi_prod[PW-1:ZFRAC];
    assign zone_idx = (zi_q_reg >= (PW-ZFRAC)'(ZONES)) ? ZW'(ZONES-1) : zi_q_reg[ZW-1:0];

    localparam int ZC  = ZONES / 2;        // centre zone
    localparam int ZQ1 = ZONES / 4;        // quarter / three-quarter zones (dual)
    localparam int ZQ3 = (3 * ZONES) / 4;

    // ---- smooth sweep: a one-zone-wide column glides L->R by pixels and wraps
    //      (scol = floor(frame[7:0]*STRX/256) — ~one zone-width every few frames). ----
    localparam int COLW = (H_ACTIVE / ZONES < 1) ? 1 : H_ACTIVE / ZONES;  // one zone wide
    localparam int STRX = (H_ACTIVE - COLW < 1) ? 1 : H_ACTIVE - COLW;    // travel span
    logic [8+HCOORD_W-1:0] sprod;
    logic [HCOORD_W-1:0]   scol;
    logic [HCOORD_W-1:0]   x_q;
    logic [VCOORD_W-1:0]   y_q;
    logic [2:0]            sub_q;
    logic                  flash_q;
    logic                  sweep_on;
    assign sprod    = frame[7:0] * (8+HCOORD_W)'(STRX);
    assign sweep_on = (x_q >= scol) && (x_q < scol + HCOORD_W'(COLW));

    always_ff @(posedge clk) begin
        if (rst) begin
            zi_q_reg <= '0;
            scol     <= '0;
            x_q      <= '0;
            y_q      <= '0;
            sub_q    <= '0;
            flash_q  <= 1'b0;
        end else begin
            zi_q_reg <= zi_q;
            scol     <= sprod[8+HCOORD_W-1:8];
            x_q      <= x;
            y_q      <= y;
            sub_q    <= sub;
            flash_q  <= frame[5];
        end
    end

    // ---- vertical windows / bands (compile-time y ranges) ----
    localparam int YW_H = V_ACTIVE / 8;                 // YWIN window height
    localparam int YW_T = V_ACTIVE / 16;
    localparam int YW_M = (V_ACTIVE - YW_H) / 2;
    localparam int YW_B = V_ACTIVE - YW_H - V_ACTIVE / 16;
    logic in_ywin_y;
    assign in_ywin_y = ((y_q >= VCOORD_W'(YW_T)) && (y_q < VCOORD_W'(YW_T + YW_H))) ||
                       ((y_q >= VCOORD_W'(YW_M)) && (y_q < VCOORD_W'(YW_M + YW_H))) ||
                       ((y_q >= VCOORD_W'(YW_B)) && (y_q < VCOORD_W'(YW_B + YW_H)));

    localparam int HB_H = V_ACTIVE / 12;                // HBAND band height
    localparam int HB_T = V_ACTIVE / 8;
    localparam int HB_M = (V_ACTIVE - HB_H) / 2;
    localparam int HB_B = V_ACTIVE - HB_H - V_ACTIVE / 8;
    logic in_hband;
    assign in_hband = ((y_q >= VCOORD_W'(HB_T)) && (y_q < VCOORD_W'(HB_T + HB_H))) ||
                      ((y_q >= VCOORD_W'(HB_M)) && (y_q < VCOORD_W'(HB_M + HB_H))) ||
                      ((y_q >= VCOORD_W'(HB_B)) && (y_q < VCOORD_W'(HB_B + HB_H)));

    // ---- bottom subtitle blocks (closest to a bottom-edge LED bar) ----
    localparam int SBY0 = (V_ACTIVE * 7) / 8;
    localparam int SBY1 = SBY0 + (V_ACTIVE / 16) + 1;
    localparam int SB1L = H_ACTIVE / 8,        SB1R = SB1L + H_ACTIVE / 6;
    localparam int SB2L = (H_ACTIVE * 5) / 12, SB2R = SB2L + H_ACTIVE / 4;
    localparam int SB3L = (H_ACTIVE * 3) / 4,  SB3R = SB3L + H_ACTIVE / 8;
    logic in_subt;
    assign in_subt = (y_q >= VCOORD_W'(SBY0)) && (y_q < VCOORD_W'(SBY1)) &&
                     (((x_q >= HCOORD_W'(SB1L)) && (x_q < HCOORD_W'(SB1R))) ||
                      ((x_q >= HCOORD_W'(SB2L)) && (x_q < HCOORD_W'(SB2R))) ||
                      ((x_q >= HCOORD_W'(SB3L)) && (x_q < HCOORD_W'(SB3R))));

    // ---- sub-pattern mux ----
    always_comb begin
        case (sub_q)
            3'd0:    rgb = (zone_idx == ZW'(ZC))                        ? WHITE : BLACK; // COLUMN
            3'd1:    rgb = sweep_on                                     ? WHITE : BLACK; // SWEEP (smooth)
            3'd2:    rgb = ((zone_idx == ZW'(ZC)) && in_ywin_y)         ? WHITE : BLACK; // YWIN
            3'd3:    rgb = zone_idx[0]                                  ? BLACK : WHITE; // ALTZONES (even white)
            3'd4:    rgb = in_hband                                     ? WHITE : BLACK; // HBAND
            3'd5:    rgb = in_subt                                      ? WHITE : BLACK; // SUBTITLE
            3'd6:    rgb = ((zone_idx == ZW'(ZC)) && flash_q)           ? WHITE : BLACK; // FLASH
            default: rgb = ((zone_idx == ZW'(ZQ1)) || (zone_idx == ZW'(ZQ3))) ? WHITE : BLACK; // DUAL
        endcase
    end

    // unused for lint: high frame bits, and the fractional (low) product bits.
    logic _unused;
    assign _unused = &{1'b0, frame[FRAME_W-1:8], zi_prod[ZFRAC-1:0], sprod[7:0]};
endmodule
