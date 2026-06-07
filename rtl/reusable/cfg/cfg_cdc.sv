// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_cdc (STUB — implemented in M1)
// Config clock-domain crossing (PRD §8.6, FR-CFG-2). Crosses the shadow config
// bundle from the control domain into the pixel domain with a handshake (no
// bit-tearing). M1 implements the toggle/ack handshake and bundle register.
module cfg_cdc #(
    parameter int W = 32
)(
    input  logic         src_clk,
    input  logic         dst_clk,
    input  logic         dst_rst,
    input  logic [W-1:0] src_data,
    input  logic         src_valid,
    output logic [W-1:0] dst_data,
    output logic         dst_valid
);
    // STUB: no data crossed until M1.
    assign dst_data  = '0;
    assign dst_valid = 1'b0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, src_clk, dst_clk, dst_rst, src_data, src_valid};
endmodule
