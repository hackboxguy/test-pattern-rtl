// SPDX-License-Identifier: MIT
// test-pattern-rtl — board common — dvi_tmds_encoder
//
// DVI 1.0 TMDS 8b/10b channel encoder (clean-room from the spec algorithm).
// Generic, vendor-neutral logic: transition-minimization (XOR/XNOR) followed by
// DC-balancing via a running-disparity counter. During blanking (de=0) it emits
// the four control tokens selected by ctrl = {c1, c0}. The Gowin-specific 10:1
// serializer and differential output buffer wrap this (boards/tangnano9k/).
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
    function automatic logic [3:0] ones8(input logic [7:0] v);
        logic [3:0] s;
        s = '0;
        for (int i = 0; i < 8; i++) s += 4'(v[i]);
        return s;
    endfunction

    // Transition-minimised 9-bit word (XOR or XNOR chain).
    function automatic logic [8:0] tmin(input logic [7:0] d, input logic xm);
        logic [8:0] q;
        q[0] = d[0];
        for (int i = 1; i < 8; i++)
            q[i] = xm ? ~(q[i-1] ^ d[i]) : (q[i-1] ^ d[i]);
        q[8] = xm ? 1'b0 : 1'b1;
        return q;
    endfunction

    // ---- Stage 1: transition minimisation (combinational) ----
    logic [3:0] n1d;
    logic       xnor_mode;
    logic [8:0] qm;
    assign n1d       = ones8(din);
    assign xnor_mode = (n1d > 4'd4) || (n1d == 4'd4 && din[0] == 1'b0);
    assign qm        = tmin(din, xnor_mode);

    // ---- Stage 2: DC balancing (sequential) ----
    logic [3:0]        n1q, n0q;
    logic signed [7:0] diff;       // n1q - n0q, range -8..8
    always_comb begin
        n1q  = ones8(qm[7:0]);
        n0q  = 4'd8 - n1q;
        diff = $signed({4'b0, n1q}) - $signed({4'b0, n0q});
    end

    logic signed [7:0] cnt;        // running disparity
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt  <= '0;
            dout <= 10'd0;
        end else if (!de) begin
            cnt <= '0;             // disparity resets each blanking interval
            unique case (ctrl)
                2'b00:   dout <= 10'b1101010100;
                2'b01:   dout <= 10'b0010101011;
                2'b10:   dout <= 10'b0101010100;
                default: dout <= 10'b1010101011;
            endcase
        end else begin
            if (cnt == 0 || n1q == n0q) begin
                dout[9]   <= ~qm[8];
                dout[8]   <= qm[8];
                dout[7:0] <= qm[8] ? qm[7:0] : ~qm[7:0];
                cnt       <= qm[8] ? (cnt + diff) : (cnt - diff);
            end else if ((cnt > 0 && n1q > n0q) || (cnt < 0 && n0q > n1q)) begin
                dout[9]   <= 1'b1;
                dout[8]   <= qm[8];
                dout[7:0] <= ~qm[7:0];
                cnt       <= cnt + (qm[8] ? 8'sd2 : 8'sd0) - diff;
            end else begin
                dout[9]   <= 1'b0;
                dout[8]   <= qm[8];
                dout[7:0] <= qm[7:0];
                cnt       <= cnt - (qm[8] ? 8'sd0 : 8'sd2) + diff;
            end
        end
    end
endmodule
