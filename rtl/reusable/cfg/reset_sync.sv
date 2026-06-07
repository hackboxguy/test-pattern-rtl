// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — reset_sync
// Async-assert / sync-deassert reset synchroniser. Produces the portable
// active-high synchronous reset convention (PRD §15) from an external
// async-active-low reset. One of the named CDC modules (PRD §15, FR-AUTO-CLK-4).
module reset_sync #(
    parameter int STAGES = 2
)(
    input  logic clk,
    input  logic arst_n,   // async, active-low reset input
    output logic srst      // synchronous, active-high reset output
);
    logic [STAGES-1:0] sync_q;

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) sync_q <= '1;
        else         sync_q <= {sync_q[STAGES-2:0], 1'b0};
    end

    assign srst = sync_q[STAGES-1];
endmodule
