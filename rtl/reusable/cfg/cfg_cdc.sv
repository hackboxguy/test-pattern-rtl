// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_cdc
//
// Handshake (MCP) data clock-domain crossing for the config bundle (PRD §8.6,
// FR-CFG-2). The whole bundle crosses coherently — no bit-tearing — because the
// source holds `hold` stable from the request toggle until the acknowledge
// returns. Use for occasionally-changing config; throughput is one transfer per
// round-trip (src_busy high meanwhile).
module cfg_cdc #(
    parameter int W = 32
)(
    // source (control) domain
    input  logic         src_clk,
    input  logic         src_rst,
    input  logic [W-1:0] src_data,
    input  logic         src_update,   // pulse: start a transfer of src_data
    output logic         src_busy,      // high while a transfer is in flight
    // destination (pixel) domain
    input  logic         dst_clk,
    input  logic         dst_rst,
    output logic [W-1:0] dst_data,      // coherent, stable between updates
    output logic         dst_update     // 1-cycle pulse when dst_data refreshes
);
    // --- source domain ---
    logic         req_tgl;                 // toggles per accepted transfer
    logic [W-1:0] hold;                     // stable payload (MCP path)
    logic         ack_sync0, ack_sync1;     // dst ack toggle synced to src
    wire          src_idle = (req_tgl == ack_sync1);

    assign src_busy = ~src_idle;

    always_ff @(posedge src_clk) begin
        if (src_rst) begin
            req_tgl   <= 1'b0;
            hold      <= '0;
            ack_sync0 <= 1'b0;
            ack_sync1 <= 1'b0;
        end else begin
            ack_sync0 <= ack_tgl;
            ack_sync1 <= ack_sync0;
            if (src_update && src_idle) begin
                hold    <= src_data;
                req_tgl <= ~req_tgl;
            end
        end
    end

    // --- destination domain ---
    logic ack_tgl;
    logic req_sync0, req_sync1, req_sync2;

    always_ff @(posedge dst_clk) begin
        if (dst_rst) begin
            ack_tgl    <= 1'b0;
            req_sync0  <= 1'b0;
            req_sync1  <= 1'b0;
            req_sync2  <= 1'b0;
            dst_data   <= '0;
            dst_update <= 1'b0;
        end else begin
            req_sync0  <= req_tgl;
            req_sync1  <= req_sync0;
            req_sync2  <= req_sync1;
            dst_update <= 1'b0;
            if (req_sync1 != req_sync2) begin   // new request edge -> capture
                dst_data   <= hold;             // hold is stable (src is idle until ack)
                dst_update <= 1'b1;
                ack_tgl    <= req_sync1;         // acknowledge back to source
            end
        end
    end
endmodule
