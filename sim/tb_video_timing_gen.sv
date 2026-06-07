// SPDX-License-Identifier: MIT
// tb_video_timing_gen — self-checking timing test (PRD §13).
// Validates one full frame: active pixel count, eol count, sof delimiting,
// first-pixel coordinate, sync pulse totals, coordinate range, frame increment.
// Geometry is parameterized (override with -GH / -GV) to cover odd sizes.
module tb_video_timing_gen #(
    parameter int H = 32,
    parameter int V = 24
)();
    localparam int HFP = 2, HS = 2, HBP = 2;
    localparam int VFP = 1, VS = 1, VBP = 1;
    localparam int H_TOTAL = H + HFP + HS + HBP;
    localparam int V_TOTAL = V + VFP + VS + VBP;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic        rst;
    logic        de, hsync, vsync, sof, eol;
    logic [11:0] x0, yv;
    logic [23:0] frame;

    video_timing_gen #(
        .H_ACTIVE(H), .H_FP(HFP), .H_SYNC(HS), .H_BP(HBP),
        .V_ACTIVE(V), .V_FP(VFP), .V_SYNC(VS), .V_BP(VBP),
        .HSYNC_POL(1'b1), .VSYNC_POL(1'b1)
    ) dut (
        .clk(clk), .rst(rst),
        .de(de), .hsync(hsync), .vsync(vsync), .sof(sof), .eol(eol),
        .x0(x0), .y(yv), .frame(frame)
    );

    int errors = 0;
    int de_cnt, eol_cnt, hs_cnt, vs_cnt, first;
    logic [23:0] frame_start;

    task automatic measure_frame();
        begin
            de_cnt = 0; eol_cnt = 0; hs_cnt = 0; vs_cnt = 0; first = 1;
            frame_start = frame;
            forever begin
                if (de) begin
                    de_cnt++;
                    if (int'(x0) >= H || int'(yv) >= V) begin
                        errors++; $display("COORD OOR x=%0d y=%0d", x0, yv);
                    end
                    if (first) begin
                        if (x0 != 12'd0 || yv != 12'd0) begin
                            errors++; $display("FIRST PIXEL not (0,0): (%0d,%0d)", x0, yv);
                        end
                        first = 0;
                    end
                end
                if (eol)          eol_cnt++;
                if (hsync == 1'b1) hs_cnt++;
                if (vsync == 1'b1) vs_cnt++;
                @(posedge clk);
                if (sof) break;
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);
        while (!sof) @(posedge clk);

        measure_frame();

        if (de_cnt  != H * V)         begin errors++; $display("de_cnt=%0d exp=%0d",  de_cnt,  H*V); end
        if (eol_cnt != V)             begin errors++; $display("eol_cnt=%0d exp=%0d", eol_cnt, V); end
        if (hs_cnt  != HS * V_TOTAL)  begin errors++; $display("hs_cnt=%0d exp=%0d",  hs_cnt,  HS*V_TOTAL); end
        if (vs_cnt  != VS * H_TOTAL)  begin errors++; $display("vs_cnt=%0d exp=%0d",  vs_cnt,  VS*H_TOTAL); end
        if (frame   != frame_start + 24'd1) begin errors++; $display("frame !++ %0d->%0d", frame_start, frame); end

        if (errors == 0) $display("RESULT: PASS  vtg geom=%0dx%0d", H, V);
        else             $display("RESULT: FAIL  vtg geom=%0dx%0d errors=%0d", H, V, errors);
        if (errors != 0) $fatal(1, "vtg test failed");
        $finish;
    end

    initial begin
        #(20000000);
        $display("RESULT: FAIL vtg timeout");
        $fatal(1, "timeout");
    end
endmodule
