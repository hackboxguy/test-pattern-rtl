// SPDX-License-Identifier: MIT
// test-pattern-rtl - Tier 4 (Arty Z7-20) - 10:1 TMDS serializer lane
//
// Xilinx 7-series OSERDESE2 DDR width expansion: master emits D1 first, so
// data[0] is the first serial bit, matching the portable DVI encoder and the
// Gowin OSER10 lane contract. For DATA_WIDTH=10 the slave contributes D3/D4.
module artyz7_tmds_lane (
    input  logic       pixel_clk,
    input  logic       serial_clk,
    input  logic       rst,
    input  logic [9:0] data,
    output wire        tmds_p,
    output wire        tmds_n
);
`ifdef ARTYZ7_BEHAV
    logic       serial_q;
    logic [9:0] shift_q;
    logic [3:0] bit_q;

    always @(posedge serial_clk or negedge serial_clk or posedge rst) begin
        if (rst) begin
            serial_q <= 1'b0;
            shift_q  <= 10'd0;
            bit_q    <= 4'd0;
        end else begin
            if (bit_q == 4'd0) begin
                serial_q <= data[0];
                shift_q  <= {1'b0, data[9:1]};
                bit_q    <= 4'd1;
            end else begin
                serial_q <= shift_q[0];
                shift_q  <= {1'b0, shift_q[9:1]};
                bit_q    <= (bit_q == 4'd9) ? 4'd0 : (bit_q + 1'b1);
            end
        end
    end

    assign tmds_p = serial_q;
    assign tmds_n = ~serial_q;
`else
    wire serial_o;
    wire shift1;
    wire shift2;

    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .INIT_OQ(1'b0),
        .INIT_TQ(1'b1),
        .SERDES_MODE("MASTER"),
        .SRVAL_OQ(1'b0),
        .SRVAL_TQ(1'b1),
        .TBYTE_CTL("FALSE"),
        .TBYTE_SRC("FALSE"),
        .TRISTATE_WIDTH(1)
    ) u_master (
        .OQ(serial_o),
        .OFB(),
        .TQ(),
        .TFB(),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .TBYTEOUT(),
        .CLK(serial_clk),
        .CLKDIV(pixel_clk),
        .D1(data[0]),
        .D2(data[1]),
        .D3(data[2]),
        .D4(data[3]),
        .D5(data[4]),
        .D6(data[5]),
        .D7(data[6]),
        .D8(data[7]),
        .OCE(1'b1),
        .RST(rst),
        .SHIFTIN1(shift1),
        .SHIFTIN2(shift2),
        .T1(1'b0),
        .T2(1'b0),
        .T3(1'b0),
        .T4(1'b0),
        .TBYTEIN(1'b0),
        .TCE(1'b1)
    );

    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .INIT_OQ(1'b0),
        .INIT_TQ(1'b1),
        .SERDES_MODE("SLAVE"),
        .SRVAL_OQ(1'b0),
        .SRVAL_TQ(1'b1),
        .TBYTE_CTL("FALSE"),
        .TBYTE_SRC("FALSE"),
        .TRISTATE_WIDTH(1)
    ) u_slave (
        .OQ(),
        .OFB(),
        .TQ(),
        .TFB(),
        .SHIFTOUT1(shift1),
        .SHIFTOUT2(shift2),
        .TBYTEOUT(),
        .CLK(serial_clk),
        .CLKDIV(pixel_clk),
        .D1(1'b0),
        .D2(1'b0),
        .D3(data[8]),
        .D4(data[9]),
        .D5(1'b0),
        .D6(1'b0),
        .D7(1'b0),
        .D8(1'b0),
        .OCE(1'b1),
        .RST(rst),
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .T1(1'b0),
        .T2(1'b0),
        .T3(1'b0),
        .T4(1'b0),
        .TBYTEIN(1'b0),
        .TCE(1'b1)
    );

    OBUFDS #(
        .IOSTANDARD("TMDS_33"),
        .SLEW("FAST")
    ) u_obuf (
        .I(serial_o),
        .O(tmds_p),
        .OB(tmds_n)
    );
`endif
endmodule
