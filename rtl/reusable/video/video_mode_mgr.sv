// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 2 (video) — video_mode_mgr (STUB — implemented in M4)
// AUTO fallback supervisor (PRD §8.8.1, FR-AUTO-CLK). MUST run on the always-on
// management clock so it survives loss of the recovered pixel clock. M4
// implements the state machine (INTERNAL_FREE_RUN / EXT_LOCKING /
// EXT_LOCKED_INSERT / EXT_LOCK_LOST / FALLBACK_INTERNAL), debounce/hysteresis,
// abrupt reset-based clock-source switch, and relock policy.
module video_mode_mgr (
    input  logic mgmt_clk,          // always-on management clock
    input  logic mgmt_rst,
    input  logic src_pixclk_valid,
    input  logic cap_locked,
    output logic sel_local,         // -> timing_source_mux
    output logic fallback_active,
    output logic out_video_rst_req  // -> Tier 4 output PHY reset/blank
);
    // STUB: hold local VTG selected, no fallback asserted until M4.
    assign sel_local        = 1'b1;
    assign fallback_active  = 1'b0;
    assign out_video_rst_req = 1'b0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, mgmt_clk, mgmt_rst, src_pixclk_valid, cap_locked};
endmodule
