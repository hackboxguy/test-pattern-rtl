// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (control adapter) — gpio_button_ctrl (STUB — M2)
// Pluggable control adapter: debounced GPIO button -> pattern_sel cycling, used
// on the Tang Nano 9K (PRD §8.9, FR-CTRL-2). NOT part of the Tier 0 portability
// surface. M2 implements debounce + wrap-around cycling during board bring-up.
module gpio_button_ctrl #(
    parameter int PATSEL_W = 4
)(
    input  logic                clk,
    input  logic                rst,
    input  logic                btn,
    output logic [PATSEL_W-1:0] pattern_sel
);
    // STUB: pattern 0 (black) until M2.
    assign pattern_sel = '0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, clk, rst, btn};
endmodule
