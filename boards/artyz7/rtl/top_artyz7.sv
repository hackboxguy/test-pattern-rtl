// SPDX-License-Identifier: MIT
// test-pattern-rtl - Tier 4 (Arty Z7-20) - HDMI source top
//
// PL-only free-running pattern generator: 125 MHz oscillator -> 7-series MMCM
// -> video_source_core -> portable DVI/TMDS encoders -> OSERDESE2 + OBUFDS.
// DVI channel map: ch0=Blue(+ {vsync,hsync}), ch1=Green, ch2=Red.
`include "video_modes.svh"
`include "pattern_ids.svh"

`ifndef LD1D_ZONES
`define LD1D_ZONES 48
`endif

module top_artyz7 (
    input  logic       clk125,
    input  logic [3:0] btn,
    input  logic       hdmi_tx_hpdn,
    inout  wire        hdmi_tx_scl,
    inout  wire        hdmi_tx_sda,
    inout  wire        hdmi_tx_cec,
    output logic [3:0] led,
    output wire  [2:0] hdmi_tx_d_p,
    output wire  [2:0] hdmi_tx_d_n,
    output wire        hdmi_tx_clk_p,
    output wire        hdmi_tx_clk_n
);
    // Mode-selected MMCM values from a 125 MHz input. CLKOUT0 is the 5x TMDS
    // serializer clock; CLKOUT1 is the pixel clock.
`ifdef BUILD_1080P
    localparam real MMCM_MULT_F  = 59.375; // VCO 742.1875 MHz
    localparam int  MMCM_DIVCLK  = 10;
    localparam real MMCM_SER_DIV = 1.000;  // 742.1875 MHz
    localparam int  MMCM_PIX_DIV = 5;      // 148.4375 MHz
`elsif BUILD_720P
    localparam real MMCM_MULT_F  = 59.375; // VCO 742.1875 MHz
    localparam int  MMCM_DIVCLK  = 10;
    localparam real MMCM_SER_DIV = 2.000;  // 371.09375 MHz
    localparam int  MMCM_PIX_DIV = 10;     // 74.21875 MHz
`elsif BUILD_1024X768
    localparam real MMCM_MULT_F  = 5.200;  // VCO 650.0 MHz
    localparam int  MMCM_DIVCLK  = 1;
    localparam real MMCM_SER_DIV = 2.000;  // 325.0 MHz
    localparam int  MMCM_PIX_DIV = 10;     // 65.0 MHz
`elsif BUILD_800X600
    localparam real MMCM_MULT_F  = 8.000;  // VCO 1000.0 MHz
    localparam int  MMCM_DIVCLK  = 1;
    localparam real MMCM_SER_DIV = 5.000;  // 200.0 MHz
    localparam int  MMCM_PIX_DIV = 25;     // 40.0 MHz
`else
    localparam real MMCM_MULT_F  = 50.375; // VCO 629.6875 MHz
    localparam int  MMCM_DIVCLK  = 10;
    localparam real MMCM_SER_DIV = 5.000;  // 125.9375 MHz
    localparam int  MMCM_PIX_DIV = 25;     // 25.1875 MHz
`endif

    logic serial_clk;
    logic pixel_clk;
    logic mmcm_locked;

    artyz7_clkgen #(
        .CLKFBOUT_MULT_F(MMCM_MULT_F),
        .DIVCLK_DIVIDE(MMCM_DIVCLK),
        .CLKOUT0_DIVIDE_F(MMCM_SER_DIV),
        .CLKOUT1_DIVIDE(MMCM_PIX_DIV)
    ) u_clk (
        .clk125(clk125),
        .rst(btn[0]),
        .serial_clk(serial_clk),
        .pixel_clk(pixel_clk),
        .locked(mmcm_locked)
    );

    logic rst_pix;
    reset_sync #(.STAGES(3)) u_rst (
        .clk(pixel_clk),
        .arst_n(~btn[0] & mmcm_locked),
        .srst(rst_pix)
    );

    logic [4:0] pattern_sel;
    gpio_button_ctrl #(
        .PATSEL_W(5),
        .N_PATTERNS(`PAT_COUNT),
        .RESET_SEL(`PAT_COLOR_BARS),
        .ACTIVE_LOW(1'b0)
    ) u_btn (
        .clk(pixel_clk),
        .rst(rst_pix),
        .btn(btn[1]),
        .pattern_sel(pattern_sel)
    );

    logic        de;
    logic        hsync;
    logic        vsync;
    logic        sof;
    logic        eol;
    logic [11:0] x0;
    logic [11:0] y;
    logic [23:0] frame;
    logic [23:0] rgb;

    video_source_core #(
`ifdef BUILD_1080P
        `VMODE_1920x1080p60,
`elsif BUILD_720P
        `VMODE_1280x720p60,
`elsif BUILD_1024X768
        `VMODE_1024x768p60,
`elsif BUILD_800X600
        `VMODE_800x600p60,
`else
        `VMODE_640x480p60,
`endif
        .COLOR_W(8),
        .PATSEL_W(5),
        .LD1D_ZONES(`LD1D_ZONES)
    ) u_src (
        .clk(pixel_clk),
        .rst(rst_pix),
        .pat_en(1'b1),
        .pattern_sel(pattern_sel),
        .param('0),
        .de(de),
        .hsync(hsync),
        .vsync(vsync),
        .sof(sof),
        .eol(eol),
        .x0(x0),
        .y(y),
        .frame(frame),
        .rgb(rgb)
    );

    wire [7:0] red = rgb[23:16];
    wire [7:0] grn = rgb[15:8];
    wire [7:0] blu = rgb[7:0];

    logic [9:0] q0;
    logic [9:0] q1;
    logic [9:0] q2;
    dvi_tmds_encoder u_e0 (
        .clk(pixel_clk), .rst(rst_pix), .din(blu), .ctrl({vsync, hsync}), .de(de), .dout(q0)
    );
    dvi_tmds_encoder u_e1 (
        .clk(pixel_clk), .rst(rst_pix), .din(grn), .ctrl(2'b00), .de(de), .dout(q1)
    );
    dvi_tmds_encoder u_e2 (
        .clk(pixel_clk), .rst(rst_pix), .din(red), .ctrl(2'b00), .de(de), .dout(q2)
    );

    artyz7_tmds_lane u_l0 (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst_pix),
        .data(q0), .tmds_p(hdmi_tx_d_p[0]), .tmds_n(hdmi_tx_d_n[0])
    );
    artyz7_tmds_lane u_l1 (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst_pix),
        .data(q1), .tmds_p(hdmi_tx_d_p[1]), .tmds_n(hdmi_tx_d_n[1])
    );
    artyz7_tmds_lane u_l2 (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst_pix),
        .data(q2), .tmds_p(hdmi_tx_d_p[2]), .tmds_n(hdmi_tx_d_n[2])
    );

`ifdef TMDS_CLK_ALT
    localparam logic [9:0] TMDS_CLK_WORD = 10'b0000011111;
`else
    localparam logic [9:0] TMDS_CLK_WORD = 10'b1111100000;
`endif
    artyz7_tmds_lane u_lc (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst_pix),
        .data(TMDS_CLK_WORD), .tmds_p(hdmi_tx_clk_p), .tmds_n(hdmi_tx_clk_n)
    );

    wire hpd_present = ~hdmi_tx_hpdn;
    assign hdmi_tx_scl = 1'bz;
    assign hdmi_tx_sda = 1'bz;
    assign hdmi_tx_cec = 1'bz;

    always_comb begin
        led[0] = mmcm_locked;
        led[1] = hpd_present;
        led[2] = pattern_sel[0];
        led[3] = pattern_sel[4];
    end

    wire _unused = &{1'b0, btn[3:2], sof, eol, x0, y, frame};
endmodule
