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

| Mode | Hardware result |
|---|---|
| **640x480p60** (default) | ✅ **All 18 patterns clean** on real HDMI — recommended mode. 126 MHz serial, comfortable for the GW1NR-9C emulated-LVDS. |
| **1280x720p60** | ⚠️ Builds & timing-closes, displays, but **marginal on the board's emulated-LVDS** (371 MHz serial): colored vertical lines at value transitions on gradients, and placement-sensitive (small RTL changes can tip the green/blue lanes, including the sync-carrying blue lane → momentary sync loss). |
| **1920x1080p60** | ❌ Not buildable — rPLL CLKOUT caps at 600 MHz (needs 742.5). |

The portable cores are simulation-verified (`make sim`) and the 480p hardware
result confirms the RTL is correct: the 720p artifacts are the **ELVDS PHY at its
margin**, not a logic bug (R=G=B is emitted; the lines are physical, at value
transitions). The same resolution-independent core would run clean at higher
rates on a board with true-LVDS / a faster serializer.

> History: an earlier nextpnr-gowin 0.6 build packed a bitstream but showed a
> blank screen — root-caused to the missing CLKDIV (see toolchain note above).

## Build & flash

```bash
source <path-to>/oss-cad-suite/environment      # nextpnr-himbaechel + yosys
./boards/tangnano9k/flow/build.sh                # 640x480p60 (default)
RES=720p ./boards/tangnano9k/flow/build.sh       # 1280x720p60
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
```

Expected on screen: color bars (upscaled by the monitor). Press **S2** to cycle
patterns; **S1** resets. 480p is confirmed working on hardware; 720p meets timing
(Fmax ≈ 78 MHz > 74.25 MHz) — the TMDS encoder is pipelined (latency 2) to close.

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

Build with `RES=480p|720p|1080p ./boards/tangnano9k/flow/build.sh`.

| Mode | pixel / serial | IDIV / FBDIV / ODIV | Status |
|---|---|---|---|
| 640x480p60  | 25.2 / 126.0 MHz   | 2 / 13 / 4 | ✅ all patterns clean (recommended) |
| 1280x720p60 | 74.25 / 371.25 MHz | 3 / 54 / 2 | ⚠️ marginal on ELVDS (gradient/transition artifacts) |
| 1920x1080p60| 148.5 / 742.5 MHz  | 1 / 54 / 2 | ❌ **NOT BUILDABLE** on this board |

**1080p60 is not achievable on the Tang Nano 9K (GW1NR-9C)** — a hard limit, not a
tuning issue:
- rPLL CLKOUT max is **600 MHz**; 742.5 MHz serial is rejected by gowin_pack
  (`CLKOUT = 742.5MHz not in range 3.125 - 600MHz`).
- Even ignoring that, the fabric Fmax (~94 MHz) is far below the 148.5 MHz pixel
  clock 1080p needs.

720p60 is the practical maximum for this board. A 1080p monitor still displays
720p (upscaled). Native 1080p needs a more capable FPGA — the portable core is
resolution-independent (sim-verified at arbitrary geometries), so the same RTL
runs at 1080p on a board whose PLL/serializer can reach 1.485 Gb/s.

## Pin map (verified vs Sipeed example)

`clk`=52 (27 MHz) · `resetn`=4 (S1) · `key`=3 (S2) · TMDS data 71/70, 73/72,
75/74 · TMDS clock 69/68. TLVDS pairs constrained on the `*_p` nets (the `*_n`
auto-pair).
