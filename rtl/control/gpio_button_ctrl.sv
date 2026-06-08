// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (control adapter) — gpio_button_ctrl
//
// Pluggable control adapter: a debounced push-button advances pattern_sel,
// wrapping at N_PATTERNS (PRD §8.9, FR-CTRL-2). Used on the Tang Nano 9K. NOT
// part of the Tier 0 portability surface. Tang Nano buttons are active-low
// (pulled up), so ACTIVE_LOW defaults to 1.
module gpio_button_ctrl #(
    parameter int PATSEL_W    = 4,
    parameter int N_PATTERNS  = 14,
    parameter int RESET_SEL   = 0,     // power-on pattern index
    parameter bit ACTIVE_LOW  = 1'b1,
    parameter int DEBOUNCE_CW = 16     // ~2^CW clk cycles of debounce
)(
    input  logic                clk,
    input  logic                rst,
    input  logic                btn,
    output logic [PATSEL_W-1:0] pattern_sel
);
    // Normalize to active-high and synchronize.
    logic raw, s0, s1;
    assign raw = ACTIVE_LOW ? ~btn : btn;
    always_ff @(posedge clk) begin
        if (rst) begin s0 <= 1'b0; s1 <= 1'b0; end
        else     begin s0 <= raw;  s1 <= s0;   end
    end

    // Debounce: accept a new level only after it has been stable 2^CW cycles.
    logic [DEBOUNCE_CW-1:0] cnt;
    logic level, level_d;
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= '0; level <= 1'b0; level_d <= 1'b0;
        end else begin
            level_d <= level;
            if (s1 != level) begin
                cnt <= cnt + 1'b1;
                if (&cnt) level <= s1;
            end else begin
                cnt <= '0;
            end
        end
    end

    // Advance pattern on each clean press (rising edge of debounced level).
    wire press = level & ~level_d;
    always_ff @(posedge clk) begin
        if (rst)        pattern_sel <= PATSEL_W'(RESET_SEL);
        else if (press) pattern_sel <= (pattern_sel == PATSEL_W'(N_PATTERNS-1)) ? '0
                                                                                : (pattern_sel + 1'b1);
    end
endmodule
