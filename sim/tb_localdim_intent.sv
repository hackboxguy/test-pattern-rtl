// SPDX-License-Identifier: MIT
// tb_localdim_intent — INTENT-level checks for the local-dimming zone patterns.
//
// tb_pattern_core verifies RTL == a reference formula (catches regressions). This
// instead asserts PROPERTIES the patterns must hold regardless of how the zone
// index is computed, so it catches "intent drift" the mirroring reference cannot:
//   - a single-zone column lands exactly at floor(i*H/ZONES) boundaries (+-1 px),
//   - alternating-zones has ZONES-1 transitions across a line and zone 0 is white,
//   - dual-highlight lights zones ZONES/4 and 3*ZONES/4 only,
//   - the 2D zone checker is a true 8x8 (7 transitions across an active line).
module tb_localdim_intent #(
    parameter int H  = 240,
    parameter int V  = 24,
    parameter int ZN = 40
)();
    localparam int PAT_CHK     = 20;   // 2D coarse 8x8 zone checker
    localparam int PAT_COLUMN  = 24;   // 1D centre-zone column
    localparam int PAT_ALT     = 27;   // 1D alternating zones
    localparam int PAT_DUAL    = 31;   // 1D dual highlight
    localparam int ZC  = ZN / 2;
    localparam int ZQ1 = ZN / 4;
    localparam int ZQ3 = (3 * ZN) / 4;

    logic clk = 1'b0; always #5 clk = ~clk;
    logic rst, pat_en;
    logic [4:0]   pattern_sel;
    logic [127:0] param; assign param = '0;
    logic de, hsync, vsync, sof, eol;
    logic [11:0]  x0, yv;
    logic [23:0]  frame, rgb;

    video_source_core #(
        .H_ACTIVE(H), .H_FP(2), .H_SYNC(2), .H_BP(2),
        .V_ACTIVE(V), .V_FP(1), .V_SYNC(1), .V_BP(1),
        .HSYNC_POL(1'b1), .VSYNC_POL(1'b1),
        .COLOR_W(8), .HCOORD_W(12), .VCOORD_W(12), .FRAME_W(24),
        .PATSEL_W(5), .NPARAM(4), .PARAM_W(32), .LD1D_ZONES(ZN)
    ) dut (
        .clk(clk), .rst(rst), .pat_en(pat_en),
        .pattern_sel(pattern_sel), .param(param),
        .de(de), .hsync(hsync), .vsync(vsync), .sof(sof), .eol(eol),
        .x0(x0), .y(yv), .frame(frame), .rgb(rgb)
    );

    int  errors = 0;
    logic wcol [0:H-1];   // per-column "is white" captured from one frame's active region

    function automatic int edge_of(input int i);   // intended zone boundary
        return (i * H) / ZN;
    endfunction

    // latch the pattern (commit-on-sof), then record white-per-column for one frame
    task automatic capture(input int pat);
        int c;
        begin
            pattern_sel = 5'(pat);
            repeat (2) begin @(posedge clk); while (!sof) @(posedge clk); end
            for (c = 0; c < H; c++) wcol[c] = 1'b0;
            @(posedge clk); while (!sof) @(posedge clk);
            forever begin
                if (de) wcol[x0] = (rgb == 24'hFFFFFF);
                @(posedge clk);
                if (sof) break;
            end
        end
    endtask

    task automatic expect_eq(input string what, input int got, input int exp, input int tol);
        if (got < exp - tol || got > exp + tol) begin
            errors++;
            $display("INTENT FAIL [%s]: got %0d, expected %0d (+-%0d)", what, got, exp, tol);
        end
    endtask

    task automatic expect_true(input string what, input logic cond);
        if (!cond) begin errors++; $display("INTENT FAIL [%s]", what); end
    endtask

    int lo, hi, c, trans;
    initial begin
        rst = 1'b1; pat_en = 1'b0; pattern_sel = 5'd0;
        repeat (4) @(posedge clk); rst = 1'b0; pat_en = 1'b1;

        // COLUMN: white exactly in zone ZC = [edge(ZC), edge(ZC+1))
        capture(PAT_COLUMN);
        lo = -1; hi = -1;
        for (c = 0; c < H; c++) if (wcol[c]) begin if (lo < 0) lo = c; hi = c; end
        expect_eq("column left",  lo,     edge_of(ZC),     1);
        expect_eq("column right", hi + 1, edge_of(ZC + 1), 1);

        // ALTZONES: ZONES-1 transitions across a line; zone 0 (even) is white
        capture(PAT_ALT);
        trans = 0; for (c = 1; c < H; c++) if (wcol[c] != wcol[c-1]) trans++;
        expect_eq("altzones transitions", trans, ZN - 1, 1);
        expect_true("altzones zone0 white", wcol[0]);

        // DUAL: zones ZQ1 and ZQ3 white, centre zone black
        capture(PAT_DUAL);
        expect_true("dual ZQ1 white", wcol[(edge_of(ZQ1) + edge_of(ZQ1 + 1)) / 2]);
        expect_true("dual ZQ3 white", wcol[(edge_of(ZQ3) + edge_of(ZQ3 + 1)) / 2]);
        expect_true("dual centre black", !wcol[(edge_of(ZC) + edge_of(ZC + 1)) / 2]);

        // 2D zone checker: a true 8x8 -> 7 transitions across an active line
        capture(PAT_CHK);
        trans = 0; for (c = 1; c < H; c++) if (wcol[c] != wcol[c-1]) trans++;
        expect_eq("2D checker transitions/line", trans, 7, 0);

        if (errors == 0) $display("RESULT: PASS  localdim-intent H=%0d ZONES=%0d", H, ZN);
        else             $display("RESULT: FAIL  localdim-intent H=%0d ZONES=%0d errors=%0d", H, ZN, errors);
        if (errors != 0) $fatal(1, "intent test failed");
        $finish;
    end

    initial begin #60000000; $fatal(1, "tb_localdim_intent timeout"); end
endmodule
