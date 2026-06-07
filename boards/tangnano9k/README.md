# boards/tangnano9k/ — Tier 4 wrapper (Sipeed Tang Nano 9K, GW1NR-9C)

Drives HDMI (DVI/TMDS) test patterns at **640x480p60** (first light-up).
27 MHz → Gowin rPLL (CLKOUT = 5× pixel, CLKOUTD = pixel) → `video_source_core`
→ 3× DVI TMDS encoders → Gowin OSER10 serializers → TLVDS HDMI. The TMDS clock
channel carries the pixel clock directly (apicula DVI topology). Button **S2**
cycles patterns; **S1** resets.

## Build status

| Stage | Status |
|---|---|
| Portable cores (`video_source_core`, `dvi_tmds_encoder`, `gpio_button_ctrl`, `reset_sync`) | Simulation-verified (`make sim`). |
| **Full Gowin flow** (synth_gowin → nextpnr-gowin → gowin_pack) | **Builds clean → bitstream** with yosys 0.33, nextpnr-gowin 0.6, apicula. 14% slices. |
| **On-screen display** (real HDMI monitor) | **Not yet confirmed** — flash and verify on hardware. |

These files instantiate Gowin primitives, so they are not Verilator-linted (the
lint/yosys-smoke gates cover `rtl/` + `boards/common/`); they are validated by
the build flow instead.

## Build & flash

Requires `yosys` (synth_gowin), `nextpnr-gowin`, `gowin_pack` (apicula),
`openFPGALoader`.

```bash
./boards/tangnano9k/flow/build.sh
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
```

Expected on screen: a test pattern (default = pattern 0, black; press **S2** to
cycle through white/red/green/blue, grays, color bars, ramps, checker, grid).

## Notes / decisions

- **Clocking without CLKDIV.** Classic `nextpnr-gowin` 0.6 can't place a `CLKDIV`
  cell here, so the pixel clock is taken from the rPLL's `CLKOUTD` (÷5) output
  instead — both clocks from one rPLL. (The newer `nextpnr-himbaechel` flow does
  support CLKDIV if you switch toolchains.)
- **rPLL `DEVICE`** must be `"GW1NR-9C"` (the real part); nextpnr-gowin rejects
  `"GW1N-9C"` even though the *family* flag is `GW1N-9C`.
- **TMDS clock channel** = pixel clock straight through a TLVDS buffer (no 4th
  serializer), matching the apicula DVI example.

## Resolution / bring-up ladder

Default 640x480p60. To go higher, set the `VMODE_*` macro in
`top_tangnano9k.sv` **and** the rPLL dividers in `gowin_tmds_clkgen.sv`:

| Mode | pixel / serial | IDIV / FBDIV / ODIV (SDIV=5) | Notes |
|---|---|---|---|
| 640x480p60  | 25.2 / 126.0 MHz   | 2 / 13 / 4 | **default, build-validated** |
| 1280x720p60 | 74.25 / 371.25 MHz | 3 / 54 / 2 | must-pass target; re-verify timing |
| 1920x1080p60| 148.5 / 742.5 MHz  | —          | serial exceeds rPLL VCO range; stretch (PRD risk) |

## Pin map (verified vs Sipeed example)

`clk`=52 (27 MHz) · `resetn`=4 (S1) · `key`=3 (S2) · TMDS data 71/70, 73/72,
75/74 · TMDS clock 69/68. TLVDS pairs constrained on the `*_p` nets (the `*_n`
auto-pair).
