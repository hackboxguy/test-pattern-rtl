# Porting & custom-timing guide

How to (1) add a fixed-timing panel, (2) add a generic test resolution, and
(3) bring up a new FPGA/board — written so a future you or a future Claude Code
session can extend timings/boards quickly. For the hard-won board gotchas
(himbaechel, ELVDS-not-TLVDS, the seed/lock issue, etc.) see [`../CLAUDE.md`](../CLAUDE.md).

## The one idea: timings are portable, clocks/PHY are board-specific

The reusable core (`rtl/reusable/`, Tier 0–3) is vendor-neutral and takes video
timing as plain parameters. Everything device-specific (PLL, serializers, I/O,
constraints, build flow) lives in `boards/<board>/` (Tier 4).

| Concern | Where | Portable? |
|---|---|---|
| Video timing (H/V active·FP·sync·BP, polarities) | `video_source_core` params | ✅ |
| Pattern engine, VTG, zones | `rtl/reusable/**` | ✅ |
| DVI/TMDS 8b/10b encoder | `boards/common/dvi_tmds_encoder.sv` | ✅ |
| Pixel/serial **clock generation** (dividers, PLL primitive) | `boards/<board>/` clock-gen | ❌ board-specific |
| **Serialization** (10:1) + **output buffer** (differential/PHY) | `boards/<board>/` | ❌ |
| Pin **constraints**, **build flow** | `boards/<board>/` | ❌ |

Two layers carry timing into a build:
- `rtl/reusable/video/video_modes.svh` — named `VMODE_*` macros (portable timing
  bundles) for the generic test resolutions and sim.
- `boards/<board>/displays.conf` + `PANEL=<name>` — a board table of real panels
  (timings + pixel clock + LED-zone count); the PLL dividers are **solved** at build.

## Recipe 1 — add a fixed-timing panel (existing Tang Nano board)

1. Add a row to [`../boards/tangnano9k/displays.conf`](../boards/tangnano9k/displays.conf)
   (numbers from the panel EDID/datasheet or [`video-timings.md`](video-timings.md)):
   ```
   # name   HACT HFP HSY HBP  VACT VFP VSY VBP  HPOL VPOL  PIXMHZ  ZONES
   my-panel 1920 50  50  54   720  21  2   18   0    0     94.52   40
   ```
   `PIXMHZ` = pixel clock; `ZONES` = LED count (0 if not a 1D-dimming panel);
   `HPOL/VPOL` = sync polarity (0 = negative).
2. Build: `PANEL=my-panel ./boards/tangnano9k/flow/build.sh`. The build emits the
   timing defines, sets `ZONES`/`PIXFREQ`, and **solves** the rPLL dividers from
   `PIXMHZ`. No RTL edits. (`PANEL` overrides `RES`; without it, `RES=`/`ZONES=`
   are unchanged — `PANEL` is opt-in.)
3. The build checks the limits for you (see *Hard limits* below) and either errors
   (clock > rPLL cap) or flags EXPERIMENTAL (over the ELVDS cliff) and packs anyway.

## Recipe 2 — add a generic test resolution (a reusable VESA/CEA mode)

For a standard resolution you'll reuse (not a one-off panel). Three small edits
mirroring the existing modes:
1. `rtl/reusable/video/video_modes.svh` — add `VMODE_<name>` (timing bundle).
2. `boards/tangnano9k/rtl/top_tangnano9k.sv` — add an `` `elsif BUILD_<NAME> `` to
   **both** ifdef chains: the `VMODE_*` selection *and* the `PLL_IDIV/FBDIV/ODIV`
   localparams (compute dividers by hand, or copy what `PANEL=`'s solver prints).
3. `boards/tangnano9k/flow/build.sh` — add `RES=<name>) DEFINES="-DBUILD_<NAME>"; PIXFREQ=<MHz> ;;`.

For a one-off real panel prefer Recipe 1 (one row, auto-solved PLL).

## Recipe 3 — bring up a new FPGA/board

The portable core is unchanged; you write a new `boards/<board>/` wrapper. Use the
Tang Nano as the reference:

| Piece | Tang Nano reference | Your board |
|---|---|---|
| Board top | `rtl/top_tangnano9k.sv` (instantiates `video_source_core` + clock-gen + encoders + lanes + I/O) | same shape, vendor primitives swapped |
| Clock gen | `rtl/gowin_tmds_clkgen.sv` (rPLL + CLKDIV /5) | your PLL/MMCM → pixel + serial(bit) clock |
| Serializer | `rtl/gowin_tmds_lane.sv` (OSER10, 10:1 DDR) | OSERDES/ODDR/SERDES |
| Output buffer | `ELVDS_OBUF` | `OBUFDS` / true-LVDS / dedicated TMDS-HDMI PHY |
| Encoder | `boards/common/dvi_tmds_encoder.sv` — **reuse as-is** | reuse (or your PHY's own 8b/10b) |
| Constraints | `hdmi.cst` + `.sdc` | `.xdc` / `.lpf` / … |
| Build flow | `flow/build.sh` (yosys→nextpnr→gowin_pack) | your toolchain; keep the `RES=`/`PANEL=`/`ZONES=` knobs |
| PLL solver | `pll_solve()` in `build.sh` (Gowin rPLL ranges) | re-tune for your PLL (below) |

What changes per board, and where:
- **PLL solver** — `pll_solve()` hard-codes the GW1NR-9C rPLL: input `27.0` MHz,
  `CLKOUT` 3.125–600, `VCO` 400–1200, 6-bit IDIV/FBDIV. Update these for your PLL
  (or write a board-local solver).
- **Serialization ratio** — Gowin OSER10 is 10:1 **DDR** ⇒ `serial_clk = 5 × pixel`.
  A 10:1 **SDR** SERDES ⇒ `serial_clk = 10 × pixel`. Adjust the clock-gen and the
  solver's target.
- **Output-PHY clean ceiling** — per board (Tang Nano emulated-LVDS ≈ 325 MHz
  serial; a true-LVDS/HDMI-PHY board is far higher). Update the EXPERIMENTAL
  threshold (`$SER > 330`) in `build.sh`.
- **Pin/I-O standard** — board constraints file.

Reused unchanged: `rtl/reusable/**`, `boards/common/dvi_tmds_encoder.sv`,
`video_modes.svh`, and the `displays.conf` format.

## Build knobs (reference)

| Env | Meaning | Default |
|---|---|---|
| `RES=` | generic test resolution (`480p`/`800x600`/`1024x768`/`720rb`/`1920x720`/`720p`/`1080p`) | `480p` |
| `PANEL=` | named fixed-timing panel from `displays.conf` (overrides `RES`) | (none) |
| `ZONES=` | 1D local-dimming LED/zone count | 48 (or the panel's) |
| `NEXTPNR_SEED=` | P&R seed (`r` = random) | 2 |
| `SERIALIZE_CLK=1` / `CLK_ALT=1` | serialize the TMDS clock / flip its phase | off |
| `./build.sh report` | re-print the last build's timing+resource report | — |

## Hard limits to sanity-check before a build (Tang Nano 9K)

1. **rPLL CLKOUT ≤ 600 MHz** ⇒ serial = pixel×5 ≤ 600 ⇒ **pixel ≤ ~120 MHz**.
2. **Fabric Fmax** (encoder critical path, ~86–112 MHz) ≥ pixel clock.
3. **ELVDS clean ceiling** ≈ **325 MHz serial** (≈ 65 MHz pixel). Above → artifacts.
4. **12-bit coordinates** ⇒ H_total and V_total ≤ 4095. The 27″ panel (H_total 4248)
   exceeds this — bump `HCOORD_W`/`VCOORD_W` to 13 (a `video_source_core` parameter)
   for very wide modes.
