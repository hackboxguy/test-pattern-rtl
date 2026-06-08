# boards/tangnano9k/ — Tier 4 wrapper (Sipeed Tang Nano 9K, GW1NR-9C)

Drives HDMI (DVI/TMDS) test patterns at **640x480p60** (first light-up).
27 MHz → Gowin rPLL (CLKOUT = 5× pixel) → CLKDIV(/5) → `video_source_core`
→ 3× DVI TMDS encoders → Gowin OSER10 serializers → TLVDS HDMI. The TMDS clock
channel carries the pixel clock directly (apicula DVI topology). Button **S2**
cycles patterns; **S1** resets.

## Toolchain — requires OSS CAD Suite (nextpnr-himbaechel)

The CLKDIV-based clocking needs **`nextpnr-himbaechel`** + a modern Yosys, both in
**OSS CAD Suite**. The older Debian `nextpnr-gowin` 0.6 **cannot place CLKDIV**
(apicula's own CLKDIV example fails on it too); the CLKOUTD/no-CLKDIV workaround
mis-phases the OSER10 serializers → blank screen. So: install OSS CAD Suite.

```bash
# one-time
source <path-to>/oss-cad-suite/environment
```

## Build status

| Stage | Status |
|---|---|
| Portable cores (`video_source_core`, `dvi_tmds_encoder`, `gpio_button_ctrl`, `reset_sync`) | Simulation-verified (`make sim`). |
| Gowin build (synth_gowin → nextpnr-himbaechel → gowin_pack) | Author-validated against apicula DVI; **build/display to be confirmed with OSS CAD Suite**. |
| On-screen display | Pending himbaechel build + flash. |

> History: an earlier nextpnr-gowin 0.6 build packed a bitstream but showed a
> blank screen — root-caused to the missing CLKDIV (see toolchain note above).

## Build & flash

```bash
source <path-to>/oss-cad-suite/environment      # nextpnr-himbaechel + yosys
./boards/tangnano9k/flow/build.sh
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
```

Expected on screen: color bars at 640×480 (upscaled by the monitor). Press **S2**
to cycle patterns; **S1** resets.

## Notes / decisions

- **CLKDIV needs himbaechel.** Classic nextpnr-gowin 0.6 has no CLKDIV BEL
  support; OSER10 requires its pixel clock (PCLK) from CLKDIV(/5) for the correct
  phase, so himbaechel is mandatory for this design.
- **rPLL `DEVICE` = `"GW1N-9C"`** for the himbaechel flow (matches apicula
  PLL480). (Classic nextpnr-gowin wanted `"GW1NR-9C"` — different checker.)
- **TMDS clock channel** = pixel clock straight through a TLVDS buffer (no 4th
  serializer), matching the apicula DVI example.

## Resolution / bring-up ladder

Default 640x480p60. To go higher, set the `VMODE_*` macro in
`top_tangnano9k.sv` **and** the rPLL dividers in `gowin_tmds_clkgen.sv`:

| Mode | pixel / serial | IDIV / FBDIV / ODIV | Notes |
|---|---|---|---|
| 640x480p60  | 25.2 / 126.0 MHz   | 2 / 13 / 4 | default (apicula PLL480) |
| 1280x720p60 | 74.25 / 371.25 MHz | 3 / 54 / 2 | must-pass target; re-verify timing |
| 1920x1080p60| 148.5 / 742.5 MHz  | —          | serial exceeds rPLL VCO range; stretch (PRD risk) |

## Pin map (verified vs Sipeed example)

`clk`=52 (27 MHz) · `resetn`=4 (S1) · `key`=3 (S2) · TMDS data 71/70, 73/72,
75/74 · TMDS clock 69/68. TLVDS pairs constrained on the `*_p` nets (the `*_n`
auto-pair).
