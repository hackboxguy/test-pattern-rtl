// SPDX-License-Identifier: MIT
// tb_pattern_core — self-checking render test for video_source_core (PRD §13).
// For every v1 pattern: aligns to a frame, renders all active pixels to a PPM
// (sim/out/), and checks each pixel against an independent reference model that
// mirrors the pattern spec. Also checks blanking pixels are black (FR-SB-3) and
// the active pixel count. Geometry/params overridable with -G for odd sizes.
module tb_pattern_core #(
    parameter int H    = 32,
    parameter int V    = 24,
    parameter int CHK  = 2,   // checker block log2
    parameter int GP   = 2,   // grid pitch log2
    parameter int LW   = 1,   // grid line width
    parameter int FRAC = 12
)();
    localparam int COLOR_W = 8;
    localparam logic [7:0] G25 = 8'(8'hFF >> 2);
    localparam logic [7:0] G50 = 8'(8'hFF >> 1);
    localparam logic [7:0] G75 = 8'(8'hFF - (8'hFF >> 2));
    localparam int INV_H = ((1 << (COLOR_W + FRAC)) + (H / 2)) / H;
    localparam int INV_V = ((1 << (COLOR_W + FRAC)) + (V / 2)) / V;
    localparam int PITCH = (1 << GP);
    localparam int STAIR_BITS = 4;   // must match pattern_pixel_core
    localparam int STAIR_MUL  = ((1 << COLOR_W) - 1) / ((1 << STAIR_BITS) - 1);  // 255/15 = 17

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic         rst, pat_en;
    logic [3:0]   pattern_sel;
    logic [127:0] param;
    logic         de, hsync, vsync, sof, eol;
    logic [11:0]  x0, yv;
    logic [23:0]  frame, rgb;

    assign param = '0;

    video_source_core #(
        .H_ACTIVE(H), .H_FP(2), .H_SYNC(2), .H_BP(2),
        .V_ACTIVE(V), .V_FP(1), .V_SYNC(1), .V_BP(1),
        .HSYNC_POL(1'b1), .VSYNC_POL(1'b1),
        .COLOR_W(COLOR_W), .HCOORD_W(12), .VCOORD_W(12), .FRAME_W(24),
        .PATSEL_W(4), .NPARAM(4), .PARAM_W(32),
        .CHECKER_LOG2(CHK), .GRID_PITCH_LOG2(GP), .GRID_LINE_W(LW), .RAMP_FRAC(FRAC)
    ) dut (
        .clk(clk), .rst(rst), .pat_en(pat_en),
        .pattern_sel(pattern_sel), .param(param),
        .de(de), .hsync(hsync), .vsync(vsync), .sof(sof), .eol(eol),
        .x0(x0), .y(yv), .frame(frame), .rgb(rgb)
    );

    int errors = 0;

    function automatic logic [23:0] ref_pixel(input int pat, input int x, input int yy);
        logic [7:0] r, g, b;
        int bar, k, val;
        begin
            r = 8'h00; g = 8'h00; b = 8'h00;
            case (pat)
                0:  begin                                    end // black
                1:  begin r = 8'hFF; g = 8'hFF; b = 8'hFF;   end // white
                2:  begin r = 8'hFF;                         end // red
                3:  begin g = 8'hFF;                         end // green
                4:  begin b = 8'hFF;                         end // blue
                5:  begin r = G25; g = G25; b = G25;         end
                6:  begin r = G50; g = G50; b = G50;         end
                7:  begin r = G75; g = G75; b = G75;         end
                8:  begin                                        // color bars
                        bar = 0;
                        for (k = 1; k <= 7; k++) if (x >= (k * H) / 8) bar = k;
                        case (bar)
                            0: begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end // white
                            1: begin r = 8'hFF; g = 8'hFF;            end // yellow
                            2: begin            g = 8'hFF; b = 8'hFF; end // cyan
                            3: begin            g = 8'hFF;            end // green
                            4: begin r = 8'hFF;            b = 8'hFF; end // magenta
                            5: begin r = 8'hFF;                       end // red
                            6: begin                       b = 8'hFF; end // blue
                            default: begin                            end // black
                        endcase
                    end
                9:  begin val = (x  * INV_H) >> FRAC; if (val > 255) val = 255; r = 8'(val); g = r; b = r; end
                10: begin val = (yy * INV_V) >> FRAC; if (val > 255) val = 255; r = 8'(val); g = r; b = r; end
                11: begin if (((x >> CHK) & 1) ^ ((yy >> CHK) & 1)) begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end end
                12: begin if ((x & 1) ^ (yy & 1))                   begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end end
                13: begin // grid + closing border on right/bottom edges
                        if (((x % PITCH) < LW) || ((yy % PITCH) < LW) ||
                            (x >= H - LW) || (yy >= V - LW))
                            begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                14: begin // grayscale staircase = top STAIR_BITS of ramp_h, replicated
                        val = (x * INV_H) >> FRAC; if (val > 255) val = 255;
                        r = 8'(((val >> (8 - STAIR_BITS)) * STAIR_MUL));
                        g = r; b = r;
                    end
                default: begin end
            endcase
            return {r, g, b};
        end
    endfunction

    integer fd;
    string  fname;
    int     p, pixcnt;
    logic [23:0] exprgb;

    task automatic flush_frames(input int n);
        int c;
        begin
            c = 0;
            while (c < n) begin
                @(posedge clk);
                if (sof) c++;
            end
        end
    endtask

    task automatic render_check(input int pat);
        begin
            @(posedge clk);
            while (!sof) @(posedge clk);
            fname = $sformatf("sim/out/p%02d_%0dx%0d.ppm", pat, H, V);
            fd = $fopen(fname, "w");
            $fwrite(fd, "P3\n%0d %0d\n255\n", H, V);
            pixcnt = 0;
            forever begin
                if (de) begin
                    exprgb = ref_pixel(pat, int'(x0), int'(yv));
                    if (rgb !== exprgb) begin
                        errors++;
                        if (errors <= 10)
                            $display("MISMATCH pat=%0d (x=%0d,y=%0d) got=%06h exp=%06h",
                                     pat, x0, yv, rgb, exprgb);
                    end
                    $fwrite(fd, "%0d %0d %0d\n", rgb[23:16], rgb[15:8], rgb[7:0]);
                    pixcnt++;
                end else if (rgb !== 24'h0) begin
                    errors++;
                    if (errors <= 10) $display("BLANK-NOT-BLACK pat=%0d got=%06h", pat, rgb);
                end
                @(posedge clk);
                if (sof) break;
            end
            $fclose(fd);
            if (pixcnt != H * V) begin
                errors++;
                $display("PIXCOUNT pat=%0d got=%0d exp=%0d", pat, pixcnt, H * V);
            end
        end
    endtask

    initial begin
        rst = 1'b1; pat_en = 1'b0; pattern_sel = 4'd0;
        repeat (4) @(posedge clk);
        rst = 1'b0; pat_en = 1'b1;
        for (p = 0; p <= 14; p++) begin
            pattern_sel = 4'(p);
            flush_frames(2);
            render_check(p);
        end
        if (errors == 0) $display("RESULT: PASS  patterns geom=%0dx%0d count=15", H, V);
        else             $display("RESULT: FAIL  patterns geom=%0dx%0d errors=%0d", H, V, errors);
        if (errors != 0) $fatal(1, "pattern core test failed");
        $finish;
    end

    initial begin
        #(60000000);
        $display("RESULT: FAIL pattern timeout");
        $fatal(1, "timeout");
    end
endmodule
