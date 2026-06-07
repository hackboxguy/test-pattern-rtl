// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — top_tangnano9k
//
// Board top: 27 MHz -> Gowin rPLL/CLKDIV clocks -> video_source_core (720p60
// test patterns) -> 3x DVI TMDS encoders + clock channel -> Gowin OSER10/TLVDS
// lanes -> HDMI. The S2 button cycles patterns.
//
// !! UNVERIFIED on hardware. The portable cores (video_source_core,
//    dvi_tmds_encoder, gpio_button_ctrl, reset_sync) are simulation-verified;
//    the Gowin clock/serializer/PHY wiring and constraints are NOT — they need
//    the open Gowin flow + a real board. See boards/tangnano9k/README.md.
//
// DVI channel map: ch0=Blue(+ {vsync,hsync} control), ch1=Green, ch2=Red.
`include "video_modes.svh"

module top_tangnano9k (
    input  logic       clk,         // 27 MHz oscillator  (pin 52)
    input  logic       resetn,      // button S1, active-low (pin 4)
    input  logic       key,         // button S2, active-low -> pattern cycle (pin 3)
    output logic [2:0] tmds_d_p,
    output logic [2:0] tmds_d_n,
    output logic       tmds_clk_p,
    output logic       tmds_clk_n
);
    // ---- clocks ----
    logic serial_clk, pixel_clk, pll_lock;
    gowin_tmds_clkgen u_clk (
        .clk27(clk), .resetn(resetn),
        .serial_clk(serial_clk), .pixel_clk(pixel_clk), .pll_lock(pll_lock)
    );

    // ---- pixel-domain reset: held until button released AND PLL locked ----
    logic rst_pix;
    reset_sync #(.STAGES(3)) u_rst (.clk(pixel_clk), .arst_n(resetn & pll_lock), .srst(rst_pix));

    // ---- pattern select via S2 ----
    logic [3:0] pattern_sel;
    gpio_button_ctrl #(.PATSEL_W(4), .N_PATTERNS(14), .ACTIVE_LOW(1'b1)) u_btn (
        .clk(pixel_clk), .rst(rst_pix), .btn(key), .pattern_sel(pattern_sel)
    );

    // ---- pattern source (720p60) ----
    logic        de, hsync, vsync, sof, eol;
    logic [11:0] x0, y;
    logic [23:0] frame, rgb;
    video_source_core #(`VMODE_1280x720p60, .COLOR_W(8)) u_src (
        .clk(pixel_clk), .rst(rst_pix),
        .pat_en(1'b1), .pattern_sel(pattern_sel), .param('0),
        .de(de), .hsync(hsync), .vsync(vsync), .sof(sof), .eol(eol),
        .x0(x0), .y(y), .frame(frame), .rgb(rgb)
    );
    wire [7:0] red = rgb[23:16];
    wire [7:0] grn = rgb[15:8];
    wire [7:0] blu = rgb[7:0];

    // ---- TMDS encode ----
    logic [9:0] q0, q1, q2;
    dvi_tmds_encoder u_e0 (.clk(pixel_clk), .rst(rst_pix), .din(blu), .ctrl({vsync, hsync}), .de(de), .dout(q0));
    dvi_tmds_encoder u_e1 (.clk(pixel_clk), .rst(rst_pix), .din(grn), .ctrl(2'b00),          .de(de), .dout(q1));
    dvi_tmds_encoder u_e2 (.clk(pixel_clk), .rst(rst_pix), .din(red), .ctrl(2'b00),          .de(de), .dout(q2));

    // TMDS clock channel: 5 low + 5 high per pixel (LSB first).
    localparam logic [9:0] TMDS_CLK_WORD = 10'b1111100000;

    // ---- serialize + differential output ----
    gowin_tmds_lane u_l0 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q0),
                          .tmds_p(tmds_d_p[0]), .tmds_n(tmds_d_n[0]));
    gowin_tmds_lane u_l1 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q1),
                          .tmds_p(tmds_d_p[1]), .tmds_n(tmds_d_n[1]));
    gowin_tmds_lane u_l2 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q2),
                          .tmds_p(tmds_d_p[2]), .tmds_n(tmds_d_n[2]));
    gowin_tmds_lane u_lc (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(TMDS_CLK_WORD),
                          .tmds_p(tmds_clk_p), .tmds_n(tmds_clk_n));
endmodule
