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
    parameter int FRAC = 12,
    parameter int ZN   = 48   // 1D local-dimming zones (must match the DUT)
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
    // local-dimming family params (must match pat_localdim)
    localparam int LDWW   = H / 4;
    localparam int LDWH   = V / 4;
    localparam int LDWX0  = (H - LDWW) / 2;
    localparam int LDWY0  = (V - LDWH) / 2;
    localparam int LDMTRX = H - LDWW;
    localparam int LDMAMP = (1 << ($clog2(LDMTRX) - 1));
    localparam int LDMBASX= (LDMTRX - LDMAMP) / 2;
    localparam int LDMMASK= 2 * LDMAMP - 1;
    localparam int LDSBY0 = (V * 7) / 8;
    localparam int LDSBY1 = LDSBY0 + (V / 16) + 1;
    localparam int LDB1X0 = H / 8,        LDB1X1 = LDB1X0 + H / 6;
    localparam int LDB2X0 = (H * 5) / 12, LDB2X1 = LDB2X0 + H / 4;
    localparam int LDB3X0 = (H * 3) / 4,  LDB3X1 = LDB3X0 + H / 8;
    // 1D edge-bar family params (must match pat_localdim_1d)
    localparam int ZC   = ZN / 2;
    localparam int ZQ1  = ZN / 4;
    localparam int ZQ3  = (3 * ZN) / 4;
    localparam int YW_H = V / 8;
    localparam int YW_T = V / 16;
    localparam int YW_M = (V - YW_H) / 2;
    localparam int YW_B = V - YW_H - V / 16;
    localparam int HB_H = V / 12;
    localparam int HB_T = V / 8;
    localparam int HB_M = (V - HB_H) / 2;
    localparam int HB_B = V - HB_H - V / 8;
    localparam int LD1COLW = (H / ZN < 1) ? 1 : H / ZN;     // smooth-sweep column width
    localparam int LD1STRX = (H - LD1COLW < 1) ? 1 : H - LD1COLW;
    localparam int LD1_INV_ZONE = (ZN * (1 << 12) + H / 2) / H;  // zone reciprocal (ZFRAC=12)

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic         rst, pat_en;
    logic [4:0]   pattern_sel;     // 5 bits: 32 patterns (0..31)
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
        .PATSEL_W(5), .NPARAM(4), .PARAM_W(32),
        .CHECKER_LOG2(CHK), .GRID_PITCH_LOG2(GP), .GRID_LINE_W(LW), .RAMP_FRAC(FRAC),
        .LD1D_ZONES(ZN)
    ) dut (
        .clk(clk), .rst(rst), .pat_en(pat_en),
        .pattern_sel(pattern_sel), .param(param),
        .de(de), .hsync(hsync), .vsync(vsync), .sof(sof), .eol(eol),
        .x0(x0), .y(yv), .frame(frame), .rgb(rgb)
    );

    int errors = 0;

    function automatic logic [23:0] ref_pixel(input int pat, input int x, input int yy, input int frm);
        logic [7:0] r, g, b;
        int bar, k, val, nx, ny, mph, mtri, mwx0, zidx, sel;
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
                15: begin val = (x * INV_H) >> FRAC; if (val > 255) val = 255; r = 8'(val); end // red-only
                16: begin val = (x * INV_H) >> FRAC; if (val > 255) val = 255; g = 8'(val); end // green-only
                17: begin val = (x * INV_H) >> FRAC; if (val > 255) val = 255; b = 8'(val); end // blue-only
                18: begin // LD_WINDOW
                        if (x >= LDWX0 && x < LDWX0 + LDWW && yy >= LDWY0 && yy < LDWY0 + LDWH)
                            begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                19: begin // LD_WIN_MOVE
                        mph  = frm & LDMMASK;
                        mtri = (mph < LDMAMP) ? mph : (LDMMASK - mph);
                        mwx0 = LDMBASX + mtri;
                        if (x >= mwx0 && x < mwx0 + LDWW && yy >= LDWY0 && yy < LDWY0 + LDWH)
                            begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                20: begin // LD_CHECKER_ZONE (8x8)
                        nx = (x  * INV_H) >> FRAC; if (nx > 255) nx = 255;
                        ny = (yy * INV_V) >> FRAC; if (ny > 255) ny = 255;
                        if (((nx >> (COLOR_W-3)) & 1) == ((ny >> (COLOR_W-3)) & 1))
                            begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                21: begin // LD_NEARBLACK step wedge
                        nx = (x * INV_H) >> FRAC; if (nx > 255) nx = 255;
                        case ((nx >> (COLOR_W-3)) & 7)
                            0: val = 0;  1: val = 1;  2: val = 2;  3: val = 4;
                            4: val = 8;  5: val = 16; 6: val = 32; default: val = 64;
                        endcase
                        r = 8'(val); g = r; b = r;
                    end
                22: begin // LD_SUBTITLE
                        if (yy >= LDSBY0 && yy < LDSBY1 &&
                            ((x >= LDB1X0 && x < LDB1X1) || (x >= LDB2X0 && x < LDB2X1) ||
                             (x >= LDB3X0 && x < LDB3X1)))
                            begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                23: begin // LD_FLASH
                        if ((frm >> 5) & 1) begin r = 8'hFF; g = 8'hFF; b = 8'hFF; end
                    end
                25: begin // LD1D_SWEEP (smooth: one-zone column glides L->R)
                        sel = ((frm & 255) * LD1STRX) >> 8;   // scol
                        if (x >= sel && x < sel + LD1COLW) begin r=8'hFF; g=8'hFF; b=8'hFF; end
                    end
                24, 26, 27, 30, 31: begin // 1D zone-index patterns: floor(x*ZONES/H)
                        zidx = (x * LD1_INV_ZONE) >> 12; if (zidx > ZN - 1) zidx = ZN - 1;
                        case (pat)
                            24: if (zidx == ZC) begin r=8'hFF; g=8'hFF; b=8'hFF; end          // COLUMN
                            26: if (zidx == ZC &&                                              // YWIN
                                    ((yy>=YW_T && yy<YW_T+YW_H) || (yy>=YW_M && yy<YW_M+YW_H) ||
                                     (yy>=YW_B && yy<YW_B+YW_H)))
                                    begin r=8'hFF; g=8'hFF; b=8'hFF; end
                            27: if ((zidx & 1) == 0) begin r=8'hFF; g=8'hFF; b=8'hFF; end      // ALTZONES (even white)
                            30: if (zidx == ZC && ((frm>>5)&1)) begin r=8'hFF; g=8'hFF; b=8'hFF; end // FLASH
                            31: if (zidx == ZQ1 || zidx == ZQ3) begin r=8'hFF; g=8'hFF; b=8'hFF; end // DUAL
                            default: begin end
                        endcase
                    end
                28: begin // 1D HBAND (full-width top/mid/bottom bands)
                        if ((yy>=HB_T && yy<HB_T+HB_H) || (yy>=HB_M && yy<HB_M+HB_H) ||
                            (yy>=HB_B && yy<HB_B+HB_H))
                            begin r=8'hFF; g=8'hFF; b=8'hFF; end
                    end
                29: begin // 1D SUBTITLE (same blocks as the 2D subtitle)
                        if (yy >= LDSBY0 && yy < LDSBY1 &&
                            ((x>=LDB1X0 && x<LDB1X1) || (x>=LDB2X0 && x<LDB2X1) ||
                             (x>=LDB3X0 && x<LDB3X1)))
                            begin r=8'hFF; g=8'hFF; b=8'hFF; end
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
                    exprgb = ref_pixel(pat, int'(x0), int'(yv), int'(frame));
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
        for (p = 0; p <= 31; p++) begin
            pattern_sel = 5'(p);
            flush_frames(2);
            render_check(p);
        end
        if (errors == 0) $display("RESULT: PASS  patterns geom=%0dx%0d count=32", H, V);
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
