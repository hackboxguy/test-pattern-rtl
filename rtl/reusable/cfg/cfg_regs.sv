// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_regs (STUB — implemented in M1/M3)
// Shadow config registers (PRD §8.6 / §10.4). Holds shadow pattern_sel/params
// in the control domain; commits atomically on sof downstream. M1 implements
// the shadow/active split and APPLIED_FRAME; M3 adds the full CSR map.
module cfg_regs #(
    parameter int PATSEL_W = 4,
    parameter int NPARAM   = 4,
    parameter int PARAM_W  = 32
)(
    input  logic                      clk,
    input  logic                      rst,
    // host write side (placeholder; real bus adapter in Tier 3)
    input  logic [PATSEL_W-1:0]       host_pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0] host_param,
    input  logic                      host_we,
    // shadow bundle -> cfg_cdc
    output logic [PATSEL_W-1:0]       shadow_pattern_sel,
    output logic [NPARAM*PARAM_W-1:0] shadow_param,
    output logic                      shadow_valid
);
    // STUB: parked until M1.
    assign shadow_pattern_sel = '0;
    assign shadow_param       = '0;
    assign shadow_valid       = 1'b0;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, clk, rst, host_pattern_sel, host_param, host_we};
endmodule
