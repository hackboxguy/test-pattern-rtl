# boards/tangnano9k/ — Tier 4 wrapper (Sipeed Tang Nano 9K, GW1NR-9C)

Drives HDMI (DVI/TMDS) test patterns at **720p60** (the must-pass target).
27 MHz → Gowin rPLL/CLKDIV → `video_source_core` → 3× DVI TMDS encoders + clock
channel → Gowin OSER10/TLVDS lanes → HDMI. Button **S2** cycles patterns; **S1**
resets.

## ⚠️ Validation status

| Part | Status |
|---|---|
| `video_source_core`, `dvi_tmds_encoder`, `gpio_button_ctrl`, `reset_sync` | **Simulation-verified** (`make sim`). |
| `gowin_tmds_clkgen` (rPLL+CLKDIV), `gowin_tmds_lane` (OSER10+TLVDS_OBUF), `top_tangnano9k`, `hdmi.cst/.sdc`, `flow/build.sh` | **UNVERIFIED** — authored from references; not run through P&R/bitstream and not tested on hardware here. |

These files instantiate Gowin primitives, so they are **not** Verilator-linted
(the lint gate covers `rtl/` + `boards/common/`). They need the open Gowin flow
and a real board to validate.

## Things to verify before/while bringing up

1. **rPLL dividers** (`gowin_tmds_clkgen`) — confirm/regenerate with the Gowin
   Clock Calculator for your pixel clock; check the `rPLL`/`CLKDIV` port and
   parameter names against the Gowin Primitives User Guide (SUG283).
2. **TLVDS constraint convention** — `hdmi.cst` constrains only the `*_p` nets
   with `Ppin,Npin` pairs (matching Sipeed's example). If your
   nextpnr-himbaechel/apicula version wants the `*_n` nets constrained or absent,
   adjust the cst and/or the top's `tmds_*_n` ports.
3. **Device string / part** in `flow/build.sh` (`GW1NR-LV9QN88PC6/I5`, family
   `GW1N-9C`) and the exact `nextpnr-himbaechel` invocation.
4. **TMDS clock phase / channel mapping** — if colors are swapped or the image is
   unstable, check the ch0/ch1/ch2 = B/G/R mapping and the `TMDS_CLK_WORD` phase.

## Build & flash (open toolchain)

Requires OSS CAD Suite: `yosys` (with `synth_gowin`), `nextpnr-himbaechel`
(Project Apicula), `gowin_pack`, and `openFPGALoader`.

```bash
./boards/tangnano9k/flow/build.sh
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
```

## Resolution / bring-up ladder

Default is 720p60. Per PRD §11/§18, bring up in order:

| Mode | pixel / serial | clkgen dividers | Notes |
|---|---|---|---|
| 640x480p60  | 25.2 / 126.0 MHz  | IDIV=2, FBDIV=13, ODIV=8 | safest first light-up |
| 1280x720p60 | 74.25 / 371.25 MHz | IDIV=3, FBDIV=54, ODIV=2 | **default / must-pass** |
| 1920x1080p60| 148.5 / 742.5 MHz | — | serial exceeds rPLL VCO range; stretch, may be unreachable on the open flow |

To change resolution: pick the `VMODE_*` macro in `top_tangnano9k.sv` and the
matching clkgen dividers (and update `hdmi.sdc` periods).

## Pin map (from Sipeed example, verified)

`clk`=52 (27 MHz) · `resetn`=4 (S1) · `key`=3 (S2) · TMDS data 71/70, 73/72,
75/74 · TMDS clock 69/68.
