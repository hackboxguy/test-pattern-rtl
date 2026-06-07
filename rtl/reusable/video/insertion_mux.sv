// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 2 (video) — insertion_mux (STUB body — M4)
// Mode B frame insertion (PRD §8.7, FR-CAP-4/5). INSERT_MODE selects
// REPLACE / OVERLAY / PASSTHROUGH (separate from TIMING_MODE). v1 OVERLAY is
// binary key only. M4 wires the real REPLACE/OVERLAY/PASSTHROUGH behaviour;
// this stub defaults to REPLACE (generated pixels).
module insertion_mux #(
    parameter int PIXW = 24    // 3 * COLOR_W
)(
    input  logic [1:0]      insert_mode,   // 0:REPLACE 1:OVERLAY 2:PASSTHROUGH
    input  logic            de,
    input  logic [PIXW-1:0] src_pix,
    input  logic [PIXW-1:0] gen_pix,
    input  logic            gen_key,       // binary overlay key
    output logic [PIXW-1:0] out_pix
);
    // STUB: REPLACE.
    assign out_pix = gen_pix;

    logic _unused_ok;
    assign _unused_ok = &{1'b0, insert_mode, de, src_pix, gen_key};
endmodule
