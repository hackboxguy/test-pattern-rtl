// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — gowin_tmds_lane
//
// 10:1 DDR serializer for one TMDS data channel (Gowin OSER10). The differential
// output buffers (TLVDS_OBUF) are instantiated once, vectored, in the top so the
// TMDS clock channel can carry the pixel clock directly (matching the apicula
// DVI example). NOT Verilator-lintable; validated via the open Gowin flow.
// TMDS words go out LSB-first, so D0 = data[0].
module gowin_tmds_lane (
    input  logic       pclk,    // pixel clock
    input  logic       fclk,    // 5x serial clock
    input  logic       rst,     // active-high
    input  logic [9:0] data,    // TMDS 10-bit word
    output logic       ser      // serialized output (to TLVDS_OBUF.I)
);
    OSER10 u_ser (
        .Q   (ser),
        .D0  (data[0]), .D1(data[1]), .D2(data[2]), .D3(data[3]), .D4(data[4]),
        .D5  (data[5]), .D6(data[6]), .D7(data[7]), .D8(data[8]), .D9(data[9]),
        .PCLK(pclk),
        .FCLK(fclk),
        .RESET(rst)
    );
endmodule
