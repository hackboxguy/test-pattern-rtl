// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_regs
//
// Control-domain shadow registers (PRD §8.6, FR-CFG-1). Captures host writes of
// the config bundle {pat_en, pattern_sel, param} and hands the latest value to
// cfg_cdc. Writes while a crossing is in flight (busy) keep the newest value via
// a dirty flag, which re-issues once cfg_cdc is idle. The committed-on-sof step
// happens downstream in cfg_commit.
module cfg_regs #(
    parameter int PATSEL_W = 4,
    parameter int NPARAM   = 4,
    parameter int PARAM_W  = 32
)(
    input  logic                              clk,
    input  logic                              rst,
    // host write interface
    input  logic [PATSEL_W-1:0]               w_pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0]         w_param,
    input  logic                              w_pat_en,
    input  logic                              w_strobe,
    // from cfg_cdc
    input  logic                              busy,
    // to cfg_cdc
    output logic [1+PATSEL_W+NPARAM*PARAM_W-1:0] shadow,
    output logic                              update
);
    logic dirty;

    always_ff @(posedge clk) begin
        if (rst) begin
            shadow <= '0;       // default: pat_en=0 -> black
            dirty  <= 1'b0;
            update <= 1'b0;
        end else begin
            update <= 1'b0;
            // Issue a crossing when something is staged and the CDC is idle.
            if (dirty && !busy) begin
                update <= 1'b1;
                dirty  <= 1'b0;
            end
            // A host write has priority: it refreshes the shadow and re-arms
            // dirty (so a write coincident with an issue is not lost).
            if (w_strobe) begin
                shadow <= {w_pat_en, w_pattern_sel, w_param};
                dirty  <= 1'b1;
            end
        end
    end
endmodule
