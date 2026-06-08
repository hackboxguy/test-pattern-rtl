// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 1 — video mode timing table (PRD §8.4 / §11)
//
// Each VMODE_* macro expands to the named timing parameter overrides for
// video_timing_gen / video_source_core. Use full mode names (PRD §9 / FR-CLR-5);
// `vic` is the HDMI VIC (0 = pure DMT/CVT). Sync polarity: 1 = active-high pulse.
//
//   video_source_core #(`VMODE_1280x720p60, .COLOR_W(8)) u_src (...);
//
// Standard CEA-861 / VESA-DMT timings. Verify against the standards when the
// board top is authored (PRD §22).
`ifndef VIDEO_MODES_SVH
`define VIDEO_MODES_SVH

// 640x480p60 — VGA / VESA-DMT, also HDMI VIC 1. Pixel clock 25.175 MHz. H-,V- sync.
`define VMODE_640x480p60 \
    .H_ACTIVE(640),  .H_FP(16),  .H_SYNC(96),  .H_BP(48),  \
    .V_ACTIVE(480),  .V_FP(10),  .V_SYNC(2),   .V_BP(33),  \
    .HSYNC_POL(1'b0), .VSYNC_POL(1'b0)
`define VIC_640x480p60   1

// 800x600p60 — VESA DMT. Pixel ~40 MHz (serial ~200 MHz). H+,V+ sync.
`define VMODE_800x600p60 \
    .H_ACTIVE(800),  .H_FP(40),  .H_SYNC(128), .H_BP(88),  \
    .V_ACTIVE(600),  .V_FP(1),   .V_SYNC(4),   .V_BP(23),  \
    .HSYNC_POL(1'b1), .VSYNC_POL(1'b1)
`define VIC_800x600p60   0

// 1024x768p60 — VESA DMT. Pixel ~65 MHz (serial ~325 MHz). H-,V- sync.
`define VMODE_1024x768p60 \
    .H_ACTIVE(1024), .H_FP(24),  .H_SYNC(136), .H_BP(160), \
    .V_ACTIVE(768),  .V_FP(3),   .V_SYNC(6),   .V_BP(29),  \
    .HSYNC_POL(1'b0), .VSYNC_POL(1'b0)
`define VIC_1024x768p60  0

// 1280x720p60 — CEA VIC 4. Pixel clock 74.25 MHz. H+,V+ sync.
`define VMODE_1280x720p60 \
    .H_ACTIVE(1280), .H_FP(110), .H_SYNC(40),  .H_BP(220), \
    .V_ACTIVE(720),  .V_FP(5),   .V_SYNC(5),   .V_BP(20),  \
    .HSYNC_POL(1'b1), .VSYNC_POL(1'b1)
`define VIC_1280x720p60  4

// 1920x1080p60 — CEA VIC 16. Pixel clock 148.5 MHz. H+,V+ sync.
`define VMODE_1920x1080p60 \
    .H_ACTIVE(1920), .H_FP(88),  .H_SYNC(44),  .H_BP(148), \
    .V_ACTIVE(1080), .V_FP(4),   .V_SYNC(5),   .V_BP(36),  \
    .HSYNC_POL(1'b1), .VSYNC_POL(1'b1)
`define VIC_1920x1080p60 16

`endif // VIDEO_MODES_SVH
