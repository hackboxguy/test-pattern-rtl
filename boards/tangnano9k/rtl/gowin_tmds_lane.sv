// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — gowin_tmds_lane
//
// One TMDS lane: 10:1 DDR serialization of a TMDS-encoded word followed by a
// true-LVDS differential output buffer. Instantiates Gowin GW1NR-9C primitives
// (OSER10, TLVDS_OBUF) -> NOT Verilator-lintable, NOT validated in this repo.
//
// !! UNVERIFIED on hardware. Confirm OSER10 / TLVDS_OBUF port names and behavior
//    against the Gowin Primitives User Guide (SUG283) before relying on it.
//    TMDS words are transmitted LSB-first, so D0 = data[0].
module gowin_tmds_lane (
    input  logic       pclk,    // pixel clock
    input  logic       fclk,    // 5x serial clock (DDR -> 10 bits/pixel)
    input  logic       rst,     // active-high
    input  logic [9:0] data,    // TMDS 10-bit word (LSB first on the wire)
    output logic       tmds_p,
    output logic       tmds_n
);
    logic ser;

    OSER10 u_ser (
        .Q   (ser),
        .D0  (data[0]), .D1(data[1]), .D2(data[2]), .D3(data[3]), .D4(data[4]),
        .D5  (data[5]), .D6(data[6]), .D7(data[7]), .D8(data[8]), .D9(data[9]),
        .PCLK(pclk),
        .FCLK(fclk),
        .RESET(rst)
    );

    TLVDS_OBUF u_obuf (
        .I (ser),
        .O (tmds_p),
        .OB(tmds_n)
    );
endmodule
