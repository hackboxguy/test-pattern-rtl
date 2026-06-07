// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 2 (video) — timing_measure (STUB — implemented in M4)
// Mode B captured-timing measurement (PRD §8.7, FR-CAP-2/3). M4 implements
// active/total/sync measurement, lock acquisition with hysteresis, and the
// measured-geometry outputs. Runs on the recovered source pixel clock.
module timing_measure #(
    parameter int HCOORD_W = 12,
    parameter int VCOORD_W = 12
)(
    input  logic                pclk,    // recovered source pixel clock
    input  logic                rst,
    input  logic                de,
    input  logic                hsync,
    input  logic                vsync,
    output logic                locked,
    output logic [HCOORD_W-1:0] meas_h_active,
    output logic [VCOORD_W-1:0] meas_v_active
);
    // STUB: report unlocked / zero geometry until M4.
    assign locked        = 1'b0;
    assign meas_h_active = '0;
    assign meas_v_active = '0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, pclk, rst, de, hsync, vsync};
endmodule
