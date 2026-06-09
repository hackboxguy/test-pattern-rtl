// SPDX-License-Identifier: MIT
// test-pattern-rtl - Tier 4 (Arty Z7-20) - MMCM clock generator
//
// 125 MHz PL oscillator -> MMCME2 -> TMDS serial clock (5x pixel) + pixel
// clock. The serial output is buffered through BUFIO for the OSERDESE2 CLK
// ports; the pixel clock is buffered globally and drives both fabric and
// OSERDESE2 CLKDIV. All mode-specific divider values live in top_artyz7.sv.
module artyz7_clkgen #(
    parameter real CLKFBOUT_MULT_F    = 5.940,
    parameter int  DIVCLK_DIVIDE       = 1,
    parameter real CLKOUT0_DIVIDE_F    = 1.000,  // serial clock
    parameter int  CLKOUT1_DIVIDE      = 5       // pixel clock
)(
    input  logic clk125,
    input  logic rst,
    output logic serial_clk,
    output logic pixel_clk,
    output logic locked
);
    wire clk125_i;
    wire clkfb;
    wire clkfb_buf;
    wire serial_unbuf;
    wire pixel_unbuf;

    IBUF u_clk_ibuf (
        .I(clk125),
        .O(clk125_i)
    );

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKIN1_PERIOD(8.000),
        .DIVCLK_DIVIDE(DIVCLK_DIVIDE),
        .CLKFBOUT_MULT_F(CLKFBOUT_MULT_F),
        .CLKFBOUT_PHASE(0.000),
        .CLKOUT0_DIVIDE_F(CLKOUT0_DIVIDE_F),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .CLKOUT1_DIVIDE(CLKOUT1_DIVIDE),
        .CLKOUT1_DUTY_CYCLE(0.500),
        .CLKOUT1_PHASE(0.000),
        .CLKOUT2_DIVIDE(1),
        .CLKOUT2_DUTY_CYCLE(0.500),
        .CLKOUT2_PHASE(0.000),
        .CLKOUT3_DIVIDE(1),
        .CLKOUT3_DUTY_CYCLE(0.500),
        .CLKOUT3_PHASE(0.000),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT4_DUTY_CYCLE(0.500),
        .CLKOUT4_PHASE(0.000),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT5_DUTY_CYCLE(0.500),
        .CLKOUT5_PHASE(0.000),
        .CLKOUT6_DIVIDE(1),
        .CLKOUT6_DUTY_CYCLE(0.500),
        .CLKOUT6_PHASE(0.000),
        .CLKOUT4_CASCADE("FALSE"),
        .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKIN1(clk125_i),
        .CLKFBIN(clkfb_buf),
        .CLKFBOUT(clkfb),
        .CLKFBOUTB(),
        .CLKOUT0(serial_unbuf),
        .CLKOUT0B(),
        .CLKOUT1(pixel_unbuf),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .LOCKED(locked),
        .PWRDWN(1'b0),
        .RST(rst)
    );

    BUFG u_fb_buf (
        .I(clkfb),
        .O(clkfb_buf)
    );

    BUFIO u_serial_buf (
        .I(serial_unbuf),
        .O(serial_clk)
    );

    BUFG u_pixel_buf (
        .I(pixel_unbuf),
        .O(pixel_clk)
    );
endmodule
