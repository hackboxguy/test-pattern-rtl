// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 1 (video) — video_delay
// Generic sideband alignment delay line. The Tier 1/2 wrapper delays the full
// sideband bundle by PATTERN_LATENCY so it stays aligned to rgb (PRD §8.5,
// FR-SB-5). DEPTH=0 is a pass-through.
module video_delay #(
    parameter int WIDTH = 1,
    parameter int DEPTH = 1
)(
    input  logic             clk,
    input  logic             rst,        // active-high, synchronous
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    if (DEPTH == 0) begin : g_passthrough
        assign q = d;
        logic _unused_ok;
        assign _unused_ok = &{1'b0, clk, rst};
    end else begin : g_delay
        logic [WIDTH-1:0] pipe [DEPTH];
        always_ff @(posedge clk) begin
            if (rst) begin
                for (int i = 0; i < DEPTH; i++) pipe[i] <= '0;
            end else begin
                pipe[0] <= d;
                for (int i = 1; i < DEPTH; i++) pipe[i] <= pipe[i-1];
            end
        end
        assign q = pipe[DEPTH-1];
    end
endmodule
