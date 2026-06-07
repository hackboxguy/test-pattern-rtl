// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 3 (cfg) — cfg_commit
//
// Pixel-domain atomic config commit (PRD §8.6, FR-CFG-3/4). A staged bundle
// from cfg_cdc is latched into `active` ONLY on sof, so pattern_sel and all
// params change together on a frame boundary — never mid-frame, never torn.
// Exposes cfg_pending / cfg_applied / applied_frame status (cfg_epoch).
module cfg_commit #(
    parameter int BUND_W  = 1 + 4 + 4*32,
    parameter int FRAME_W = 24
)(
    input  logic                clk,
    input  logic                rst,
    input  logic [BUND_W-1:0]   staged,
    input  logic                staged_update,   // pulse: staged refreshed
    input  logic                sof,
    input  logic [FRAME_W-1:0]  frame,
    output logic [BUND_W-1:0]   active,
    output logic                cfg_pending,
    output logic                cfg_applied,     // 1-cycle pulse on commit
    output logic [FRAME_W-1:0]  applied_frame
);
    logic pending;
    assign cfg_pending = pending;

    always_ff @(posedge clk) begin
        if (rst) begin
            active        <= '0;        // pat_en=0 -> black until first commit
            pending       <= 1'b0;
            applied_frame <= '0;
            cfg_applied   <= 1'b0;
        end else begin
            cfg_applied <= 1'b0;
            if (staged_update) pending <= 1'b1;
            if (sof && pending) begin
                active        <= staged;     // atomic bundle update
                applied_frame <= frame;
                cfg_applied   <= 1'b1;
                pending       <= 1'b0;
            end
        end
    end
endmodule
