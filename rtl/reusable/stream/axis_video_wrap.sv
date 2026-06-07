// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (stream) — axis_video_wrap (STUB — implemented in M3)
// Optional AXI4-Stream Video adapter (PRD §8.10 / §10.3). Adapter/sim use only,
// NOT the real-time PHY path. M3 implements tuser=SOF / tlast=EOL mapping plus
// the explicit stall policy (tready-required-high or FIFO) and error flags.
module axis_video_wrap #(
    parameter int PIXW = 24
)(
    input  logic            clk,
    input  logic            rst,
    // native Simple-Sync in
    input  logic            in_de,
    input  logic            in_sof,
    input  logic            in_eol,
    input  logic [PIXW-1:0] in_rgb,
    // AXI4-Stream Video out
    output logic [PIXW-1:0] m_axis_tdata,
    output logic            m_axis_tvalid,
    output logic            m_axis_tuser,   // [0] = SOF
    output logic            m_axis_tlast,   // = EOL
    input  logic            m_axis_tready
);
    // STUB: idle.
    assign m_axis_tdata  = '0;
    assign m_axis_tvalid = 1'b0;
    assign m_axis_tuser  = 1'b0;
    assign m_axis_tlast  = 1'b0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, clk, rst, in_de, in_sof, in_eol, in_rgb, m_axis_tready};
endmodule
