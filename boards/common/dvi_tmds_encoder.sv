// SPDX-License-Identifier: MIT
// test-pattern-rtl — board common — dvi_tmds_encoder
//
// DVI 1.0 TMDS 8b/10b channel encoder (clean-room from the spec algorithm).
// Generic, vendor-neutral logic: transition-minimization (XOR/XNOR) followed by
// DC-balancing via a running-disparity counter. During blanking (de=0) it emits
// the four control tokens selected by ctrl = {c1, c0}. The Gowin-specific 10:1
// serializer and differential output buffer wrap this (boards/tangnano9k/).
//
// 3-stage pipeline (LATENCY = 3): stage 1 = transition minimization, stage 2 =
// ones-count/disparity term, stage 3 = DC-balance decision + running disparity.
// Keeps the critical path short enough for 720p (and headroom for 1080p). All
// channels share the latency, so the output stays aligned.
//
// NOTE: this lives in the board tree (Tier 4 per PRD §8.10/FR-OUT-4), not the
// portable rtl/reusable/ core — TMDS/DVI is an output-PHY concern.
module dvi_tmds_encoder (
    input  logic       clk,
    input  logic       rst,        // active-high, synchronous
    input  logic [7:0] din,        // pixel byte for this channel (video)
    input  logic [1:0] ctrl,       // {c1, c0} control bits (blanking)
    input  logic       de,         // 1 = active video, 0 = blanking
    output logic [9:0] dout
);
    // Verilog-2001-style functions (accepted by both Verilator and Yosys read).
    function [3:0] ones8(input [7:0] v);
        integer i;
        reg [3:0] s;
        begin
            s = 4'd0;
            for (i = 0; i < 8; i = i + 1) s = s + 4'(v[i]);
            ones8 = s;
        end
    endfunction

    // ---- Stage 1: transition minimisation (combinational) ----
    // The DVI XOR/XNOR chain q_m[i] = q_m[i-1] (^ / ~^) d[i] equals the
    // cumulative XOR prefix with an alternating inversion in XNOR mode:
    //   q_m[i] = (^d[i:0]) ^ (xnor_mode & i[0]),   q_m[8] = ~xnor_mode.
    // Computing it as parallel prefix reductions (log depth) instead of a serial
    // 8-deep chain shortens the critical path for high pixel clocks (720p+).
    logic [3:0] n1d;
    logic       xnor_mode;
    logic [7:0] px;     // px[i] = XOR reduction of din[i:0]
    logic [8:0] qm;
    assign n1d       = ones8(din);
    assign xnor_mode = (n1d > 4'd4) || (n1d == 4'd4 && din[0] == 1'b0);
    assign px[0]     = din[0];
    assign px[1]     = ^din[1:0];
    assign px[2]     = ^din[2:0];
    assign px[3]     = ^din[3:0];
    assign px[4]     = ^din[4:0];
    assign px[5]     = ^din[5:0];
    assign px[6]     = ^din[6:0];
    assign px[7]     = ^din[7:0];
    assign qm[0]     = px[0];
    assign qm[1]     = px[1] ^ xnor_mode;
    assign qm[2]     = px[2];
    assign qm[3]     = px[3] ^ xnor_mode;
    assign qm[4]     = px[4];
    assign qm[5]     = px[5] ^ xnor_mode;
    assign qm[6]     = px[6];
    assign qm[7]     = px[7] ^ xnor_mode;
    assign qm[8]     = ~xnor_mode;

    // ---- Stage 1 register: qm ----
    logic [8:0] qm1;
    logic [1:0] ctrl1;
    logic       de1;
    always_ff @(posedge clk) begin
        if (rst) begin qm1 <= '0; ctrl1 <= '0; de1 <= 1'b0; end
        else     begin qm1 <= qm;  ctrl1 <= ctrl; de1 <= de; end
    end

    // ---- Stage 2: ones-count + disparity term (registered) ----
    logic [3:0]        n1q_c, n0q_c;
    logic signed [7:0] diff_c;
    always_comb begin
        n1q_c  = ones8(qm1[7:0]);
        n0q_c  = 4'd8 - n1q_c;
        diff_c = $signed({4'b0, n1q_c}) - $signed({4'b0, n0q_c});
    end

    logic [8:0]        qm2;
    logic [3:0]        n1q, n0q;
    logic signed [7:0] diff;
    logic [1:0]        ctrl2;
    logic              de2;
    always_ff @(posedge clk) begin
        if (rst) begin
            qm2 <= '0; n1q <= '0; n0q <= '0; diff <= '0; ctrl2 <= '0; de2 <= 1'b0;
        end else begin
            qm2 <= qm1; n1q <= n1q_c; n0q <= n0q_c; diff <= diff_c; ctrl2 <= ctrl1; de2 <= de1;
        end
    end

    // ---- Stage 3: DC-balance decision + running disparity (registered) ----
    // TMDS latency = 3. The cnt recurrence lives here on a short path (the
    // ones-count/diff are already registered in stage 2).
    logic signed [7:0] cnt;
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt  <= '0;
            dout <= 10'd0;
        end else if (!de2) begin
            cnt <= '0;             // disparity resets each blanking interval
            unique case (ctrl2)
                2'b00:   dout <= 10'b1101010100;
                2'b01:   dout <= 10'b0010101011;
                2'b10:   dout <= 10'b0101010100;
                default: dout <= 10'b1010101011;
            endcase
        end else begin
            if (cnt == 0 || n1q == n0q) begin
                dout[9]   <= ~qm2[8];
                dout[8]   <= qm2[8];
                dout[7:0] <= qm2[8] ? qm2[7:0] : ~qm2[7:0];
                cnt       <= qm2[8] ? (cnt + diff) : (cnt - diff);
            end else if ((cnt > 0 && n1q > n0q) || (cnt < 0 && n0q > n1q)) begin
                dout[9]   <= 1'b1;
                dout[8]   <= qm2[8];
                dout[7:0] <= ~qm2[7:0];
                cnt       <= cnt + (qm2[8] ? 8'sd2 : 8'sd0) - diff;
            end else begin
                dout[9]   <= 1'b0;
                dout[8]   <= qm2[8];
                dout[7:0] <= qm2[7:0];
                cnt       <= cnt - (qm2[8] ? 8'sd0 : 8'sd2) + diff;
            end
        end
    end
endmodule
