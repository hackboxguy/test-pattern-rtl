# boards/tangnano9k/ — Tier 4 wrapper (Sipeed Tang Nano 9K, GW1NR-9C)

Drives HDMI (DVI/TMDS) test patterns at **640x480p60** (first light-up).
27 MHz → Gowin rPLL (CLKOUT = 5× pixel) → CLKDIV(/5) → `video_source_core`
→ 3× DVI TMDS encoders → Gowin OSER10 serializers → **ELVDS** HDMI. The TMDS clock
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

All 24 patterns are clean on real HDMI up to **1024×768p60 (XGA)**. The
clean/artifact boundary is the emulated-LVDS **serial bit rate**:

| Mode | serial | Hardware result |
|---|---|---|
| 640×480p60 (default) | 126 MHz | ✅ clean |
| 800×600p60 | ~200 MHz | ✅ clean |
| **1024×768p60 (XGA)** | ~325 MHz | ✅ **clean — highest confirmed** |
| 1280×720p60 | 371 MHz | ❌ above the cliff — colored lines at value transitions |
| 1920×1080p60 | 742.5 MHz | ❌ not buildable (rPLL CLKOUT caps at 600 MHz) |

The portable cores are simulation-verified (`make sim`) and the clean-up-to-XGA
hardware result confirms the RTL is correct: the 720p artifacts are the **ELVDS
PHY past its rate margin** (R=G=B is emitted; the lines are physical, at value
transitions — not a logic bug). The same resolution-independent core runs clean
at higher rates on a board with true-LVDS / a faster serializer. Note the modes
above are 4:3; for native 16:9 try `RES=720rb` (720p reduced-blanking at
~319 MHz, below the cliff, if the sink accepts CVT-RB timing).

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
(fabric Fmax ~88-96 MHz, seed-dependent, > 74.25 MHz) — the TMDS encoder is a
3-stage pipeline (latency 3). Note: fabric timing closing is necessary but not
sufficient at 720p; the emulated-LVDS link itself is the real limiter.

The `openFPGALoader` line above loads **SRAM** (volatile — lost on power-cycle, so
the board reverts to the Sipeed factory demo). To make it stick, flash it (below).

## Persistent flash & factory backup

`openFPGALoader` defaults to volatile **SRAM** (`-m`); use **`-f`** to write the
on-board SPI flash so the bitstream survives a power-cycle. **Back up the Sipeed
factory image first** so you can always restore it.

```bash
# 0. inspect (read-only) — prints the FPGA + the connected SPI flash (model/size)
openFPGALoader -b tangnano9k --detect -f

# 1. BACK UP the factory image FIRST. Use the flash size from step 0; ~4 MB safely
#    covers the factory bitstream (it lives at offset 0; trailing 0xFF is unused).
openFPGALoader -b tangnano9k --dump-flash --file-size 4194304 sipeed_factory_backup.bin
ls -l sipeed_factory_backup.bin && xxd sipeed_factory_backup.bin | head   # must NOT be all-ff/00

# 2. write OUR bitstream to flash (persistent) and verify it
openFPGALoader -b tangnano9k -f --verify boards/tangnano9k/build/top_tangnano9k.fs

# 3. restore the factory image later (raw .bin written back to offset 0)
openFPGALoader -b tangnano9k -f -o 0 sipeed_factory_backup.bin
```

- **Iterate on SRAM, flash only when ready** — SRAM (the default
  `openFPGALoader -b tangnano9k <file>.fs`) is instant and unlimited; flash has
  finite write cycles. Use `-f` for the "make it stick" step, not every test build.
- `-o` is the flash **offset**, not an output file — the dump's output is the
  positional filename (`sipeed_factory_backup.bin`).
- If `-f` complains about flash selection on this part, add `--external-flash`
  (the 9K stores its config in the on-board SPI flash); plain `-f` is the normal path.

## Notes / decisions

- **CLKDIV needs himbaechel.** Classic nextpnr-gowin 0.6 has no CLKDIV BEL
  support; OSER10 requires its pixel clock (PCLK) from CLKDIV(/5) for the correct
  phase, so himbaechel is mandatory for this design.
- **rPLL `DEVICE` = `"GW1N-9C"`** for the himbaechel flow (matches apicula
  PLL480). (Classic nextpnr-gowin wanted `"GW1NR-9C"` — different checker.)
- **TMDS clock channel** = pixel clock straight through an ELVDS buffer (no 4th
  serializer) by default, matching the apicula DVI example. For 720p, building
  with `SERIALIZE_CLK=1` instead serializes the clock through a 4th OSER10 (same
  output path/phase as the data lanes) — see the 720p experiments below.

## Resolution / bring-up ladder

Default 640x480p60. To go higher, set the `VMODE_*` macro in
`top_tangnano9k.sv` **and** the rPLL dividers in `gowin_tmds_clkgen.sv`:

Build with `RES=480p|800x600|1024x768|720rb|720p|1080p ./boards/tangnano9k/flow/build.sh`.

The clean/marginal boundary is the emulated-LVDS **serial bit rate**, not the
fabric: ~200 MHz is clean, ~371 MHz is not.

| Mode | pixel / serial | IDIV / FBDIV / ODIV | Status |
|---|---|---|---|
| 640x480p60      | 25.2 / 126.0 MHz   | 2 / 13 / 4 | ✅ clean (4:3, safe baseline) |
| 800x600p60      | ~40 / ~200 MHz     | 4 / 36 / 4 | ✅ clean (4:3) |
| 1024x768p60     | ~65 / ~325 MHz     | 0 / 11 / 2 | ✅ **clean — highest confirmed (4:3 XGA)** |
| 1280x720p60 RB  | ~64.8 / 324 MHz    | 0 / 11 / 2 | ❌ 16:9, same rate/PLL as XGA but still artifacts: 1280-wide forces short blanking (~11% vs XGA's 24%), too little receiver recovery time at 324 MHz; placement-sensitive (`RES=720rb`) |
| 1280x720p60     | 74.25 / 371.25 MHz | 3 / 54 / 2 | ❌ above the ELVDS cliff (gradient/transition artifacts) |

**No 16:9 mode is reliably clean on this board.** 4:3 up to 1024x768 is the clean
ceiling. Getting 1280-wide active at a sub-cliff serial rate forces reduced
blanking, which starves the ELVDS receiver's per-line recovery -- so the 16:9
modes stay marginal regardless of PLL/seed.
| 1920x1080p60| 148.5 / 742.5 MHz  | 1 / 54 / 2 | ❌ **NOT BUILDABLE** on this board |

**1080p60 is not achievable on the Tang Nano 9K (GW1NR-9C)** — a hard limit, not a
tuning issue:
- rPLL CLKOUT max is **600 MHz**; 742.5 MHz serial is rejected by gowin_pack
  (`CLKOUT = 742.5MHz not in range 3.125 - 600MHz`).
- Even ignoring that, the fabric Fmax (~94 MHz) is far below the 148.5 MHz pixel
  clock 1080p needs.

1024×768p60 (XGA, ~325 MHz serial) is the highest confirmed-clean mode; standard
720p60 (371 MHz) is just past the ELVDS cliff. Native 1080p needs a more capable
FPGA — the portable core is resolution-independent (sim-verified at arbitrary
geometries), so the same RTL runs at 1080p on a board whose PLL/serializer can
reach 1.485 Gb/s.

## Pin map (verified vs Sipeed example)

`clk`=52 (27 MHz) · `resetn`=4 (S1) · `key`=3 (S2) · TMDS data 71/70, 73/72,
75/74 · TMDS clock 69/68. Each ELVDS net (`*_p` and `*_n`) is constrained to its
own pin (himbaechel convention).

## 720p experiments (artifact debugging)

720p builds/displays but is marginal on the board's emulated-LVDS. Build knobs
to push margin / match the clock and data output paths:

```bash
# serialize the TMDS clock through a 4th OSER10 (recommended for 720p), fixed seed
SERIALIZE_CLK=1 NEXTPNR_SEED=2 RES=720p ./boards/tangnano9k/flow/build.sh
CLK_ALT=1        # also flip the 10-bit clock pattern (clock phase) if needed
NEXTPNR_SEED=<n> # sweep seeds; the build fails 720p if serial_clk can't route on dedicated routing
```
