// SPDX-License-Identifier: MIT
// tb_dvi_tmds_encoder — self-checking test for the DVI TMDS encoder (PRD §13).
// Checks: (1) blanking emits the four control tokens; (2) every video byte
// round-trips through an independent TMDS decoder; (3) the running disparity of
// the emitted bitstream stays bounded (DC balance).
module tb_dvi_tmds_encoder;
    localparam int BOUND = 16;
    localparam int LAT   = 1;     // sampling offset = (encoder latency 2) - 1
                                  // (din is driven before the edge, absorbing one stage)

    logic       clk = 1'b0; always #5 clk = ~clk;
    logic       rst, de;
    logic [7:0] din;
    logic [1:0] ctrl;
    logic [9:0] dout;
    logic [7:0] dseq [0:1023];    // history of driven din for latency compare

    dvi_tmds_encoder dut (.clk(clk), .rst(rst), .din(din), .ctrl(ctrl), .de(de), .dout(dout));

    int errors = 0;
    int acc;

    function automatic logic [9:0] ctl_token(input logic [1:0] c);
        case (c)
            2'b00:   return 10'b1101010100;
            2'b01:   return 10'b0010101011;
            2'b10:   return 10'b0101010100;
            default: return 10'b1010101011;
        endcase
    endfunction

    function automatic logic [7:0] tmds_decode(input logic [9:0] q);
        logic [7:0] qm8, d;
        qm8  = q[9] ? ~q[7:0] : q[7:0];
        d[0] = qm8[0];
        for (int i = 1; i < 8; i++)
            d[i] = q[8] ? (qm8[i] ^ qm8[i-1]) : ~(qm8[i] ^ qm8[i-1]);
        return d;
    endfunction

    function automatic int ones10(input logic [9:0] v);
        int s; s = 0;
        for (int i = 0; i < 10; i++) s += int'(v[i]);
        return s;
    endfunction

    logic [7:0] dec;
    int i, c;

    initial begin
        rst = 1'b1; de = 1'b0; din = 8'd0; ctrl = 2'b00;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        // ---- control tokens (blanking); hold each long enough to fill pipeline ----
        de = 1'b0;
        for (c = 0; c < 4; c++) begin
            ctrl = 2'(c);
            repeat (LAT + 1) @(posedge clk);
            if (dout !== ctl_token(2'(c))) begin
                errors++;
                $display("FAIL ctrl token %0d got=%b exp=%b", c, dout, ctl_token(2'(c)));
            end
        end

        // ---- video: round-trip every value + random, track disparity ----
        // dout at step i corresponds to the din driven LAT cycles earlier.
        de  = 1'b1;
        acc = 0;
        for (i = 0; i < 256 + 512 + LAT; i++) begin
            din      = (i < 256) ? 8'(i) : 8'($random);
            dseq[i]  = din;
            @(posedge clk);
            if (i >= LAT) begin
                dec = tmds_decode(dout);
                if (dec !== dseq[i-LAT]) begin
                    errors++;
                    if (errors <= 10)
                        $display("FAIL roundtrip i=%0d din=%02h dec=%02h dout=%b",
                                 i-LAT, dseq[i-LAT], dec, dout);
                end
                acc += (2 * ones10(dout)) - 10;
                if (acc > BOUND || acc < -BOUND) begin
                    errors++;
                    $display("FAIL disparity acc=%0d at i=%0d", acc, i);
                end
            end
        end

        if (errors == 0) $display("RESULT: PASS  dvi_tmds_encoder (max|disparity| bounded by %0d)", BOUND);
        else             $display("RESULT: FAIL  dvi_tmds_encoder errors=%0d", errors);
        if (errors != 0) $fatal(1, "tmds encoder test failed");
        $finish;
    end

    initial begin
        #(200000);
        $display("RESULT: FAIL tmds timeout");
        $fatal(1, "timeout");
    end
endmodule
