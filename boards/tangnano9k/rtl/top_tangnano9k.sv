// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 4 (Tang Nano 9K) — top_tangnano9k
//
// Board top: 27 MHz -> Gowin rPLL/CLKDIV -> video_source_core (test patterns)
// -> 3x DVI TMDS encoders -> Gowin OSER10 serializers -> ELVDS HDMI.
// Resolution is build-selected: default 640x480p60, -DBUILD_720P, -DBUILD_1080P
// (1080p not buildable on this board -- see README).
// The TMDS clock channel carries the pixel clock directly (apicula DVI topology).
// Button S2 cycles patterns; S1 resets.
//
// Validated through the open Gowin flow (synth_gowin + nextpnr-gowin + gowin_pack
// -> bitstream). The portable cores are also simulation-verified. Default is
// 640x480p60 (first light-up); for 720p change the VMODE macro AND the
// gowin_tmds_clkgen dividers (see that file + the board README).
//
// DVI channel map: ch0=Blue(+ {vsync,hsync} control), ch1=Green, ch2=Red.
`include "video_modes.svh"
`include "pattern_ids.svh"

module top_tangnano9k (
    input  logic       clk,         // 27 MHz oscillator  (pin 52)
    input  logic       resetn,      // button S1, active-low (pin 4)
    input  logic       key,         // button S2, active-low -> pattern cycle (pin 3)
    output logic [2:0] tmds_d_p,
    output logic [2:0] tmds_d_n,
    output logic       tmds_clk_p,
    output logic       tmds_clk_n
);
    // ---- resolution select (default 480p; -DBUILD_720P or -DBUILD_1080P) ----
`ifdef BUILD_1080P
    localparam int PLL_IDIV = 1, PLL_FBDIV = 54, PLL_ODIV = 2;   // 742.5 MHz serial (VCO 1485 -> out of range!)
`elsif BUILD_720P
    localparam int PLL_IDIV = 3, PLL_FBDIV = 54, PLL_ODIV = 2;   // 371.25 MHz serial
`elsif BUILD_720P_RB
    localparam int PLL_IDIV = 4, PLL_FBDIV = 58, PLL_ODIV = 2;   // ~318.6 MHz serial (pixel ~63.7 MHz), 16:9 CVT-RB
`elsif BUILD_1024X768
    localparam int PLL_IDIV = 0, PLL_FBDIV = 11, PLL_ODIV = 2;   // ~324 MHz serial (pixel ~64.8 MHz)
`elsif BUILD_800X600
    localparam int PLL_IDIV = 4, PLL_FBDIV = 36, PLL_ODIV = 4;   // ~199.8 MHz serial (pixel ~40 MHz)
`else
    localparam int PLL_IDIV = 2, PLL_FBDIV = 13, PLL_ODIV = 4;   // 126.0 MHz serial
`endif

    // ---- clocks ----
    logic serial_clk, pixel_clk, pll_lock;
    gowin_tmds_clkgen #(.IDIV_SEL(PLL_IDIV), .FBDIV_SEL(PLL_FBDIV), .ODIV_SEL(PLL_ODIV)) u_clk (
        .clk27(clk), .resetn(resetn),
        .serial_clk(serial_clk), .pixel_clk(pixel_clk), .pll_lock(pll_lock)
    );

    // ---- pixel-domain reset: held until button released AND PLL locked ----
    logic rst_pix;
    reset_sync #(.STAGES(3)) u_rst (.clk(pixel_clk), .arst_n(resetn & pll_lock), .srst(rst_pix));

    // ---- pattern select via S2 (power-on = color bars) ----
    logic [4:0] pattern_sel;   // 5 bits: PAT_COUNT (18) patterns
    gpio_button_ctrl #(.PATSEL_W(5), .N_PATTERNS(`PAT_COUNT), .RESET_SEL(`PAT_COLOR_BARS),
                       .ACTIVE_LOW(1'b1)) u_btn (
        .clk(pixel_clk), .rst(rst_pix), .btn(key), .pattern_sel(pattern_sel)
    );

    // ---- pattern source (640x480p60) ----
    logic        de, hsync, vsync, sof, eol;
    logic [11:0] x0, y;
    logic [23:0] frame, rgb;
    video_source_core #(
`ifdef BUILD_1080P
        `VMODE_1920x1080p60,
`elsif BUILD_720P
        `VMODE_1280x720p60,
`elsif BUILD_720P_RB
        `VMODE_1280x720p60_RB,
`elsif BUILD_1024X768
        `VMODE_1024x768p60,
`elsif BUILD_800X600
        `VMODE_800x600p60,
`else
        `VMODE_640x480p60,
`endif
        .COLOR_W(8), .PATSEL_W(5)
    ) u_src (
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

    // ---- serialize the 3 data channels ----
    logic [2:0] ser;
    gowin_tmds_lane u_l0 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q0), .ser(ser[0]));
    gowin_tmds_lane u_l1 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q1), .ser(ser[1]));
    gowin_tmds_lane u_l2 (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix), .data(q2), .ser(ser[2]));

    // ---- TMDS clock channel + differential outputs ----
    // Tang Nano 9K HDMI pins are EMULATED LVDS -> ELVDS_OBUF (not TLVDS_OBUF).
    // Default: forward the pixel clock directly to the ELVDS buffer (proven at
    //   480p; pixel_clk feeds the buffer directly so it keeps its name in timing).
    // -DSERIALIZE_TMDS_CLK: serialize the clock through a 4th OSER10 so the clock
    //   lane matches the data lanes' output path/phase (clock/data skew at 720p).
    //   -DTMDS_CLK_ALT flips the 10-bit clock pattern (phase depends on bit order).
`ifdef SERIALIZE_TMDS_CLK
  `ifdef TMDS_CLK_ALT
    localparam logic [9:0] TMDS_CLK_WORD = 10'b0000011111;
  `else
    localparam logic [9:0] TMDS_CLK_WORD = 10'b1111100000;
  `endif
    logic ser_clk;
    gowin_tmds_lane u_lc (.pclk(pixel_clk), .fclk(serial_clk), .rst(rst_pix),
                          .data(TMDS_CLK_WORD), .ser(ser_clk));
    ELVDS_OBUF tmds_buf [3:0] (
        .I ({ser_clk,    ser}),
        .O ({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );
`else
    ELVDS_OBUF tmds_buf [3:0] (
        .I ({pixel_clk,  ser}),
        .O ({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );
`endif
endmodule
