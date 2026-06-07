// SPDX-License-Identifier: MIT
// tb_cfg_atomic — self-checking config-atomicity test for cfg_pipe (PRD §8.6 / §13).
// Two asynchronous clocks (control vs pixel). Verifies:
//   * active config changes ONLY on a commit (cfg_applied), i.e. on sof;
//   * a mid-frame write does NOT take effect until the next sof;
//   * pattern_sel and params commit atomically together (never torn);
//   * applied_frame advances per commit.
module tb_cfg_atomic;
    localparam int PATSEL_W = 4, NPARAM = 4, PARAM_W = 32, FRAME_W = 24;
    localparam int BUND_W   = 1 + PATSEL_W + NPARAM*PARAM_W;          // 133
    localparam int FRAME_LEN = 40;

    // Known full bundles {pat_en, pattern_sel, param}.
    localparam logic [BUND_W-1:0] BUND_DEFAULT = '0;
    localparam logic [BUND_W-1:0] BUND_A = {1'b1, 4'd5,  {4{32'hAAAAAAAA}}};
    localparam logic [BUND_W-1:0] BUND_B = {1'b1, 4'd11, {4{32'h55555555}}};

    logic ctrl_clk = 1'b0; always #7 ctrl_clk = ~ctrl_clk;   // period 14
    logic pix_clk  = 1'b0; always #5 pix_clk  = ~pix_clk;    // period 10

    logic ctrl_rst, pix_rst;

    // control write interface
    logic [PATSEL_W-1:0]       w_pattern_sel;
    logic [NPARAM*PARAM_W-1:0] w_param;
    logic                      w_pat_en, w_strobe, ctrl_busy;

    // pixel-domain sof/frame generator
    logic [15:0] hcnt = '0;
    logic [FRAME_W-1:0] frame = '0;
    logic sof;
    assign sof = (hcnt == 16'd0);
    always_ff @(posedge pix_clk) begin
        if (pix_rst) begin hcnt <= '0; frame <= '0; end
        else begin
            hcnt  <= (hcnt == FRAME_LEN-1) ? 16'd0 : (hcnt + 16'd1);
            if (hcnt == FRAME_LEN-1) frame <= frame + 1;
        end
    end

    logic [PATSEL_W-1:0]       active_pattern_sel;
    logic [NPARAM*PARAM_W-1:0] active_param;
    logic                      active_pat_en, cfg_pending, cfg_applied;
    logic [FRAME_W-1:0]        applied_frame;

    cfg_pipe #(.PATSEL_W(PATSEL_W), .NPARAM(NPARAM), .PARAM_W(PARAM_W), .FRAME_W(FRAME_W)) dut (
        .ctrl_clk(ctrl_clk), .ctrl_rst(ctrl_rst),
        .w_pattern_sel(w_pattern_sel), .w_param(w_param), .w_pat_en(w_pat_en), .w_strobe(w_strobe),
        .ctrl_busy(ctrl_busy),
        .pix_clk(pix_clk), .pix_rst(pix_rst), .sof(sof), .frame(frame),
        .active_pattern_sel(active_pattern_sel), .active_param(active_param), .active_pat_en(active_pat_en),
        .cfg_pending(cfg_pending), .cfg_applied(cfg_applied), .applied_frame(applied_frame)
    );

    wire [BUND_W-1:0] active = {active_pat_en, active_pattern_sel, active_param};

    int errors = 0;

    // Continuous invariant monitor.
    logic [BUND_W-1:0] active_prev;
    always_ff @(posedge pix_clk) begin
        if (!pix_rst) begin
            if (active !== active_prev && !cfg_applied) begin
                errors++; $display("FAIL active changed without commit @%0t", $time);
            end
            if (active !== BUND_DEFAULT && active !== BUND_A && active !== BUND_B) begin
                errors++; $display("FAIL torn active=%h @%0t", active, $time);
            end
        end
        active_prev <= active;
    end

    task automatic wr(input logic en, input logic [PATSEL_W-1:0] sel, input logic [NPARAM*PARAM_W-1:0] par);
        begin
            @(negedge ctrl_clk);
            w_pat_en = en; w_pattern_sel = sel; w_param = par; w_strobe = 1'b1;
            @(negedge ctrl_clk);
            w_strobe = 1'b0;
        end
    endtask

    logic [FRAME_W-1:0] af_a, af_b;

    initial begin
        w_pat_en = 0; w_pattern_sel = 0; w_param = '0; w_strobe = 0;
        ctrl_rst = 1; pix_rst = 1;
        repeat (5) @(posedge pix_clk);
        ctrl_rst = 0; pix_rst = 0;
        @(posedge pix_clk);
        if (active !== BUND_DEFAULT) begin errors++; $display("FAIL init not default"); end

        // ---- write A, expect commit on a sof ----
        wr(1'b1, 4'd5, {4{32'hAAAAAAAA}});
        do @(posedge pix_clk); while (!cfg_applied);
        af_a = applied_frame;
        @(posedge pix_clk);
        if (active !== BUND_A) begin errors++; $display("FAIL A not applied: %h", active); end

        // ---- write B mid-frame; A must persist until the next commit ----
        wr(1'b1, 4'd11, {4{32'h55555555}});
        // wait for B to stage (pending), asserting A is still active throughout
        begin
            int g; g = 0;
            while (!cfg_pending && g < 100) begin
                if (active !== BUND_A) begin errors++; $display("FAIL active!=A while staging"); end
                @(posedge pix_clk); g++;
            end
            if (!cfg_pending) begin errors++; $display("FAIL pending never set"); end
        end
        // pending set but not yet committed: A must hold until cfg_applied
        while (!cfg_applied) begin
            if (active !== BUND_A) begin errors++; $display("FAIL B applied early: %h", active); end
            @(posedge pix_clk);
        end
        af_b = applied_frame;
        @(posedge pix_clk);
        if (active !== BUND_B) begin errors++; $display("FAIL B not applied: %h", active); end
        if (af_b == af_a)      begin errors++; $display("FAIL applied_frame did not advance (%0d)", af_b); end

        repeat (20) @(posedge pix_clk);

        if (errors == 0) $display("RESULT: PASS  cfg_atomic (A@frame=%0d B@frame=%0d)", af_a, af_b);
        else             $display("RESULT: FAIL  cfg_atomic errors=%0d", errors);
        if (errors != 0) $fatal(1, "cfg atomic test failed");
        $finish;
    end

    initial begin
        #(500000);
        $display("RESULT: FAIL cfg_atomic timeout");
        $fatal(1, "timeout");
    end
endmodule
