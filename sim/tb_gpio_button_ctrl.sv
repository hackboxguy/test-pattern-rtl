// SPDX-License-Identifier: MIT
// tb_gpio_button_ctrl — self-checking debounce/cycle test (PRD §13).
// Drives bouncy active-low presses and checks pattern_sel advances exactly once
// per clean press and wraps at N_PATTERNS.
module tb_gpio_button_ctrl;
    localparam int PATSEL_W = 4, N_PATTERNS = 14, DCW = 4;  // small debounce for sim

    logic clk = 1'b0; always #5 clk = ~clk;
    logic rst, btn;
    logic [PATSEL_W-1:0] pattern_sel;

    gpio_button_ctrl #(.PATSEL_W(PATSEL_W), .N_PATTERNS(N_PATTERNS),
                       .ACTIVE_LOW(1'b1), .DEBOUNCE_CW(DCW)) dut (
        .clk(clk), .rst(rst), .btn(btn), .pattern_sel(pattern_sel)
    );

    int errors = 0;

    task automatic do_press();
        int i;
        begin
            for (i = 0; i < 6; i++) begin btn = i[0]; @(posedge clk); end // bounce
            btn = 1'b0; repeat (40) @(posedge clk);                       // settle pressed
            for (i = 0; i < 6; i++) begin btn = i[0]; @(posedge clk); end // bounce
            btn = 1'b1; repeat (40) @(posedge clk);                       // settle released
        end
    endtask

    int p;
    initial begin
        btn = 1'b1; rst = 1'b1;
        repeat (5) @(posedge clk);
        rst = 1'b0;
        repeat (5) @(posedge clk);
        if (pattern_sel != 0) begin errors++; $display("FAIL init sel=%0d", pattern_sel); end

        // 16 presses -> expect 1,2,...,13,0,1,2 (wrap at 14)
        for (p = 1; p <= 16; p++) begin
            do_press();
            if (pattern_sel != PATSEL_W'(p % N_PATTERNS)) begin
                errors++;
                $display("FAIL after press %0d: sel=%0d exp=%0d", p, pattern_sel, p % N_PATTERNS);
            end
        end

        if (errors == 0) $display("RESULT: PASS  gpio_button_ctrl");
        else             $display("RESULT: FAIL  gpio_button_ctrl errors=%0d", errors);
        if (errors != 0) $fatal(1, "gpio button test failed");
        $finish;
    end

    initial begin
        #(2000000);
        $display("RESULT: FAIL gpio timeout");
        $fatal(1, "timeout");
    end
endmodule
