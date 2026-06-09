# Handover: add a Xilinx Zynq board (clean-HDMI RTL validation)

Date: 2026-06-09 · Status: **implemented / hardware-clean through 1440p**.
Rev 3 — captures the stable Arty Z7-20 stage after bring-up.

This file started as a self-contained handover for adding a second board to
`test-pattern-rtl`. The original plan is retained below as historical context;
the current stable state is summarized first so a fresh session can continue
without re-deriving what already worked.

## Current stable state

- Board: Digilent Arty Z7-20, `xc7z020clg400-1`, PL-only HDMI source.
- Implemented under `boards/artyz7/`: MMCM clock wrapper, OSERDESE2/OBUFDS TMDS
  lane wrapper, top-level HDMI source, XDC, Vivado Tcl flow, and shell wrapper.
- Programming over JTAG/SRAM works with:
  `openFPGALoader -b arty_z7_20 boards/artyz7/build/<RES>/top_artyz7.bit`.
- Hardware validation is clean for `1080p` and `1440p`; all 32 patterns were
  visually checked clean on a 2560x1440 monitor. The 1440p pass used `ZONES=47`.
- Latest validated 1440p build: `2560x1440p59.58_RB`, 240.000 MHz pixel,
  1200.000 MHz TMDS serial, setup WNS `0.313 ns`, hold WHS `0.134 ns`,
  critical/error DRC count `0`.
- Full 1440p timing still reports an OSERDESE2 pulse-width/min-period violation
  on the 1200 MHz serial clock. The strict gate intentionally checks setup/hold
  and critical/error DRCs; keep the pulse-width caveat visible for 1440p testing.
- Pattern 25 (`LD1D_SWEEP`) is currently a timing-safe zone-stepped sweep, not a
  pixel-smooth sweep. At `ZONES=47` it advances through all zones in 256 frames
  (~4.3 s at 59.58 Hz), so it can look fast/stepped. Slowing the frame phase is
  the next planned tweak.
- The Arty Z7 shell wrapper now supports both native Linux Vivado and WSL2 with
  Windows Vivado. `build.tcl` is portable Vivado Tcl; `build.sh` selects native
  `vivado` when available, otherwise falls back to `VIVADO_BAT`.

## Why we're doing this

On the Sipeed Tang Nano 9K (GW1NR-9C), HDMI is **emulated LVDS** (`ELVDS_OBUF`).
It's clean to ~325 MHz serial (480p/800×600/1024×768) but artifacts above that, and
even XGA (325 MHz, the ragged edge) has shown **placement-sensitive** lane dropouts
(recent symptom: a red right-third on solid white = green/blue lost in transmission;
720p shows green-tinted grid lines). We believe these are the **board's PHY at its
margin, not RTL bugs** — but we can't fully prove it on a board whose PHY is the
suspect. A board with a **real TMDS output path** (true differential serializer +
OBUFDS) that runs 720p/1080p cleanly will:

1. **Build strong evidence the RTL is correct** — clean 32 patterns at 720p/1080p on a
   real PHY (same encoder/core/timings/monitor) is very strong evidence the Tang Nano
   artifacts are its ELVDS limit (see *What a clean Arty result does (and does not) prove*).
2. **Catch any genuine RTL bugs** — if the *same* artifacts (grid tint, ramp lines,
   colored edges) appear on a clean PHY, they're real and we debug them.
3. **Unlock 1080p** the Tang Nano physically can't do (rPLL 600 MHz cap), and set up
   the future **Mode B** capture/genlock milestone (Arty Z7-20 also has HDMI **IN**).

## Board recommendation: **Arty Z7-20 (XC7Z020)** — not the ZynqBerry

| | **Arty Z7-20 (XC7Z020)** ✅ | Trenz ZynqBerry TE0726 (XC7Z010) |
|---|---|---|
| HDMI | **HDMI OUT + HDMI IN** (true TMDS via OBUFDS) | micro-HDMI out, niche/constrained path |
| Fabric | 85K LC, 220 DSP, 4.9 Mb BRAM — huge headroom | 28K LC, 80 DSP — tight for video + future Mode B |
| PL clock | on-board **125 MHz PL oscillator** (PL-only designs work standalone) | clocks largely from the PS; PL-only is fiddlier |
| Video support | **extensive** Digilent reference designs (rgb2dvi/dvi2rgb), master XDC | sparse video material; RPi-form-factor I/O limits |
| Bring-up risk | low — well-trodden HDMI-out path | higher — less documentation, smaller part |

**Pick the Arty Z7-20.** It has a real differential TMDS output that does 1080p, plenty
of fabric, an independent PL oscillator (so we can run a PL-only free-running design
just like the Tang Nano), Digilent's HDMI reference material, and — bonus — **HDMI IN**
for the eventual capture/genlock (Mode B) milestone. The ZynqBerry (Z7-10) is smaller,
RPi-form-factor, and its HDMI path is far less documented — more bring-up friction for
no upside here.

## Tooling recommendation: **Vivado** for this board (portable RTL stays OSS)

The project's ethos is OSS (the Tang Nano uses OSS CAD Suite, and `make check` uses
Verilator + Yosys). Keep that — but for the **Zynq HDMI board, use Vivado**:

- **HDMI needs `OSERDESE2` (10:1 TMDS serializer, master/slave cascade) + `MMCME2` +
  precise differential I/O constraints.** These advanced primitives are exactly where
  the OSS 7-series flow (`nextpnr-xilinx` / F4PGA / Project X-Ray) is weakest — partial
  or missing OSERDESE2/MMCM support, little HDMI precedent. The goal is to validate our
  RTL *fast on a clean PHY*, not to pioneer an OSS Zynq-HDMI flow.
- **Vivado fully supports the HDMI path**, is **free** for both XC7Z020 and XC7Z010
  (Standard/WebPACK tier covers these parts), and Digilent's HDMI reference designs are
  Vivado-based.
- **Portability is preserved.** Vendor primitives live ONLY in the board wrapper
  (`boards/artyz7/`), exactly like the Gowin primitives live only in `boards/tangnano9k/`.
  The reusable core (`rtl/reusable/**`) and the **portable DVI/TMDS encoder**
  (`boards/common/dvi_tmds_encoder.sv`) stay vendor-neutral and keep passing the OSS
  `make check` gates. So the project becomes: *OSS for portable RTL + lint/sim; Vivado
  for the Xilinx board; OSS CAD Suite for the Gowin board* — each board uses its best
  toolchain.
- OSS-Zynq flow (`nextpnr-xilinx`) can be revisited *later* if full-OSS consistency
  matters, but it is **not** the path for first bring-up.

Programming: `openFPGALoader -b arty_z7_20 <bitstream>.bit` works for Zynq-7 PL over
JTAG (or use Vivado hw_server / `xsct`). So flashing need not require the Vivado GUI.

## How it fits the existing architecture (Tier 0–4)

**Reuse unchanged** (this is the whole point — we test *our* RTL):
- `rtl/reusable/**` — VTG, `video_source_core`, `pattern_pixel_core`, all 32 patterns
  (incl. the 2D/1D local-dimming families), cfg.
- `boards/common/dvi_tmds_encoder.sv` — the **portable 3-stage TMDS 8b/10b encoder**
  (this is the encoder we want to validate; do NOT swap in Digilent's rgb2dvi — that
  would only test the board, not our encoder).

**New, board-specific** under `boards/artyz7/` (Tier 4), mirroring `boards/tangnano9k/`:
- `rtl/top_artyz7.sv` — top: 125 MHz PL osc → MMCM → `video_source_core` → 3×
  `dvi_tmds_encoder` → **4× identical TMDS lanes** (ch0/1/2 data + a serialized clock
  lane) → OBUFDS → HDMI TX. Pattern cycle/reset via `gpio_button_ctrl` — **note Arty
  buttons are active-HIGH** (`.ACTIVE_LOW(1'b0)`), unlike the Tang Nano. LEDs for
  `mmcm_locked` / `hpd_present` during bring-up.
- `rtl/artyz7_clkgen.sv` — MMCM wrapper: 125 MHz → `pixel_clk` + `serial_clk` (= 5×
  pixel). Same 5× ratio as the Gowin design (OSERDESE2 DDR does 10:1 over 5×), so the
  encoder contract is identical. See **Clocking contract** below (it's more than "MMCM
  gives two clocks" — OSERDESE2 needs a specific CLK/CLKDIV + BUFIO/BUFR/BUFG topology).
- `rtl/artyz7_tmds_lane.sv` — OSERDESE2 10:1 serializer (**master+slave cascade**; a
  single OSERDESE2 maxes at 8:1) + OBUFDS for one differential pair. Drop-in analogue of
  `gowin_tmds_lane.sv` (OSER10). **The clock lane uses the SAME wrapper**, fed a fixed
  10-bit TMDS clock word (`10'b1111100000`, with a phase/bit-order flip knob) — NOT a
  raw fabric clock through OBUFDS. (Tang Nano artifacts were partly clock/data-phase
  suspect, so don't inherit an ambiguous clock path.)
- `constraints/artyz7.xdc` — HDMI TX pins (from Digilent's Arty Z7 master XDC), the
  125 MHz PL clock pin, I/O standards (TMDS_33 on the HR bank), and timing constraints
  (create_clock on the 125 MHz osc + the MMCM-derived clocks).
- `flow/build.tcl` — Vivado batch script (read sources + XDC, synth, impl, write
  bitstream). Keep the same knobs philosophy as `build.sh`: a `RES=` selecting the
  VMODE + MMCM divider settings; later a `PANEL=` reading `displays.conf`.
- `README.md` — board notes (like the Tang Nano one).

Resolution selection reuses `rtl/reusable/video/video_modes.svh` (the `VMODE_*` macros
are portable). Only the MMCM config (per pixel clock) is board-specific — analogous
to the rPLL dividers in the Tang Nano top.

## Arty Z7-20 HDMI TX pin contract

From Digilent's `Arty-Z7-20-Master.xdc` (HDMI **source** port J11). Verify against the
copy you fetch; pins below are the documented values.

| Signal | XDC name | FPGA pin | Dir | Notes |
|---|---|---:|---|---|
| `clk125` | `SYSCLK` | H16 | in | 125 MHz PL osc, `create_clock -period 8.000` |
| `hdmi_tx_d_p/n[0]` | `HDMI_TX_D0_P/N` | K17 / K18 | out | TMDS data ch0 = **blue + {vsync,hsync}** |
| `hdmi_tx_d_p/n[1]` | `HDMI_TX_D1_P/N` | K19 / J19 | out | ch1 = **green** |
| `hdmi_tx_d_p/n[2]` | `HDMI_TX_D2_P/N` | J18 / H18 | out | ch2 = **red** |
| `hdmi_tx_clk_p/n` | `HDMI_TX_CLK_P/N` | L16 / L17 | out | TMDS clock lane |
| `hdmi_tx_hpdn` | `HDMI_TX_HDPN` | R19 | in | hot-plug detect, **inverted** |
| `hdmi_tx_scl/sda` | `HDMI_TX_SCL/SDA` | M17 / M18 | inout | DDC/EDID — optional (skip for fixed DVI) |
| `hdmi_tx_cec` | `HDMI_TX_CEC` | G15 | inout | leave high-Z unless implemented |

All TMDS pairs are **`IOSTANDARD TMDS_33`** on an HR bank (true differential — the
whole point vs the Tang Nano's emulated `ELVDS_OBUF`).

## TMDS channel map (must match the Tang Nano top exactly)

A swapped channel mimics a PHY/encoder fault — and the Tang artifacts include channel
tint — so keep this explicit:

```
encoder q0 (blue + {vsync,hsync} ctrl) -> hdmi_tx_d[0]
encoder q1 (green)                      -> hdmi_tx_d[1]
encoder q2 (red)                        -> hdmi_tx_d[2]
```

## Clocking contract (7-series, not just "MMCM → two clocks")

The OSERDESE2 output path needs a specific clock network — follow Digilent's `rgb2dvi`
clocking as the reference:
- **`CLK`** = serial clock = 5× pixel (high-speed) driving the OSERDESE2 master/slave.
- **`CLKDIV`** = 1× pixel.
- **Phase alignment** between `CLK` and `CLKDIV` (both from the same MMCM).
- **Buffering**: the right `BUFIO`/`BUFR`/`BUFG` (or `BUFG`-only) usage for the I/O bank;
  practical max can be bounded by `FMAX_BUFIO` (rgb2dvi warns about this).
- **Reset** held until **MMCM lock** AND the clock buffers are stable.

Constraints: `create_clock` on the 125 MHz osc; let the MMCM derive the rest; set the
TMDS pin `IOSTANDARD`s; add `report_clock_networks` + `report_timing_summary` + DRC to
the flow. **Fail the build on negative WNS/TNS or serious DRCs.** Don't call 1080p
"clean" unless timing closes *with margin* AND the artifact matrix displays cleanly.

## Exact mode clocks (don't inherit the Tang Nano's rPLL approximations)

The Tang Nano uses 25.2 MHz for 480p because of its rPLL solution; Vivado/MMCM can hit
the **standard** clocks, so target those:

| Mode | pixel clock | serial (5×) |
|---|---|---|
| 640×480p60 | **25.175** MHz | 125.875 |
| 800×600p60 | 40.000 | 200.0 |
| 1024×768p60 | 65.000 | 325.0 |
| 1280×720p60 | 74.250 | 371.25 |
| 1920×1080p60 | 148.500 | 742.5 |

For `PANEL=` rows, solve the MMCM from `PIXMHZ` and **report actual clock + ppm error**
(mirror the Tang Nano `build.sh` reporting). A small MMCM solver or per-mode Clocking
Wizard configs both work; keep `720rb` a diagnostic mode, not the primary proof.

## Sideband policy (HPD / DDC / CEC)

- `hdmi_tx_hpdn` (R19) is an **input** (inverted) — read it, surface on an LED/status bit;
  **do not drive source HPD**. (HPA belongs to the *sink* port / future Mode B.)
- DDC/EDID: skip for fixed DVI-style output (we drive a fixed mode). If the top declares
  `scl/sda`, instantiate safe high-Z `IOBUF`s.
- CEC: leave unused / high-Z.

## Bring-up plan (suggested order for the next session)

1. **Confirm hardware + tooling**: **locate/source Vivado** (it was NOT on `PATH` in the
   review — `source <Vivado>/settings64.sh`); confirm the board is Arty Z7-**20**
   (`xc7z020clg400-1`); confirm `openFPGALoader` lists **`arty_z7_20`** (it does); fetch
   Digilent's Arty Z7 **master XDC** + `rgb2dvi` for the pins + clocking reference.
2. **Scaffold `boards/artyz7/`** (dirs above) — the **First implementation boundary**
   below is the target deliverable. Do NOT touch `rtl/reusable/**`.
3. **Clocking first**: `artyz7_clkgen.sv` per the **Clocking contract** (MMCM 125 MHz →
   **25.175** MHz pixel + 125.875 MHz serial for 480p, with the CLK/CLKDIV + BUFIO/BUFR/BUFG
   network). Lock the MMCM, get the timing reports clean, before anything else.
4. **One TMDS lane**: `artyz7_tmds_lane.sv` (OSERDESE2 10:1 **master/slave cascade** +
   OBUFDS). **Bit-order is an acceptance gate, not a note** — prove `data[0]` shifts out
   first (matching `dvi_tmds_encoder` LSB-first), via an xsim/UNISIM TB on the lane (see
   *Bit-order gate* below). The **clock lane uses the same wrapper** with a fixed TMDS
   clock word + phase-flip knob.
5. **Wire the top** at 480p, build via the Vivado flow, program, confirm color bars +
   `mmcm_locked` LED.
6. **Climb the artifact-isolation ladder** (this is the proof, so do it in this order):
   `RES=720p` (direct Tang comparison) → `RES=1024x768` (matches the Tang highest-clean
   edge) → **`PANEL=12.3-nq1 ZONES=40`** (the real custom-timing / 1D-panel target —
   bring this in early, not "later") → `RES=1080p` (high-rate stress, if timing closes
   with margin).
7. **Run the validation matrix** (below), recording evidence per row.

### First implementation boundary (the first PR/session deliverable)

Keep the first pass tight; expand after the ladder is clean:
- `boards/artyz7/rtl/{top_artyz7,artyz7_clkgen,artyz7_tmds_lane}.sv`
- `boards/artyz7/constraints/artyz7.xdc`
- `boards/artyz7/flow/build.tcl` (+ optional `build.sh` wrapper)
- `boards/artyz7/README.md`
- supports `RES=480p` and `RES=720p`; the Vivado flow reaches **route** and writes a
  `.bit` for both, **timing closed** (WNS ≥ 0, no critical DRCs)
- `make check` still passes (portable tree untouched)

Then add `PANEL=` + `RES=1024x768` + `RES=1080p` in the next step.

## Validation: what to test and what each result means

Build the **32-pattern** design at **480p, 720p, 1080p** and visually check, with
particular attention to the patterns that artifacted on the Tang Nano:

- **Grid (id 13)** — were the lines white & clean, or green/noisy? (Tang Nano 720p: green.)
- **Smooth ramp (9) / staircase (14) / R-G-B-only ramps (15–17)** — colored vertical
  lines at value transitions? (Tang Nano: yes above the cliff.)
- **Solid white (1)** across the **full width** — any spatial color shift (the XGA
  red-right-third)?
- **1-px checker (12)** — stable?
- **1D zone patterns (24–31)** at e.g. `ZONES=40` — now that zone mapping is sub-pixel
  exact, confirm boundaries land where expected (also covered by `tb_localdim_intent`).

### Validation matrix (run in this order, record evidence per row)

| Mode | Why | Expect |
|---|---|---|
| `RES=480p` | basic link/clocking sanity | color bars lock quickly |
| `RES=720p` | **direct Tang artifact comparison** | grid/ramp/white/checker clean |
| `RES=1024x768` | matches Tang's highest-clean edge | clean (incl. the solid-white test) |
| `PANEL=12.3-nq1 ZONES=40` | real custom timing + 1D panel | zone boundaries + ramps clean |
| `RES=1080p` | high-rate stress | clean if timing closes with margin |

Per row, record (photo or notes): board variant + Vivado version, build result +
**WNS/TNS + DRC status**, monitor/cable, HPD status, the **pattern IDs checked
(1, 9, 12, 13, 14, 15, 16, 17, 24–31)**, and whether artifacts are static / moving /
channel-specific / absent.

### What a clean Arty result does (and does not) prove

- **Clean on the Arty** — same encoder, same pattern core, same timings, same
  monitor/cable, same artifact-sensitive patterns — is **very strong evidence** that the
  Tang Nano issue is its Gowin/ELVDS PHY path. It does **not** prove every future mode or
  wrapper is correct.
- **Artifacts on the Arty** ⇒ debug the **new Xilinx wrapper first** (clocking topology,
  channel map, OSERDESE2 bit order, TMDS clock-lane phase, HPD/DDC, constraints) *before*
  suspecting portable RTL. Only after the wrapper is proven clean do `dvi_tmds_encoder`
  (8b/10b transition-min + running disparity) and `video_source_core` sideband alignment
  become the suspects.

## Vivado flow contract

Mirror the Tang Nano `build.sh` ergonomics. Suggested entry point:

```bash
boards/artyz7/flow/build.sh RES=720p              # wraps:
vivado -mode batch -source boards/artyz7/flow/build.tcl -tclargs RES=720p
```

The flow must:
- target part **`xc7z020clg400-1`**;
- read **only** the needed board sources + `rtl/reusable/**` + `boards/common/dvi_tmds_encoder.sv`,
  with include dirs for `pattern_ids.svh` and `video_modes.svh`;
- pass the mode defines / generated timing params + `constraints/artyz7.xdc`;
- run synth → opt → place → (phys_opt) → route → write `.bit`;
- emit **utilization, timing summary, clock-interaction, DRC, methodology** reports;
- **fail on negative WNS/TNS or critical DRCs** by default;
- print a short Tang-Nano-style summary (mode, pixel/serial clock, WNS, util).

Add a top-level `make build-artyz7` / `make report-artyz7` only **after** the flow exists.

### Bit-order gate

Make the OSERDESE2 bit order a real check, not a hope:
- xsim/UNISIM TB on `artyz7_tmds_lane` (feed a known 10-bit word, scope the serial out), or
- a behavioral LSB-first shifter behind `ifndef SYNTHESIS` so the wrapper *contract* is
  Verilator-checkable, with the OSERDESE2 behind `ifdef SYNTHESIS`.
The gate: prove **`data[0]` leaves first**, matching the Gowin lane and `dvi_tmds_encoder`.

## Key technical notes / gotchas to carry over

- **Serializer ratio is the same**: OSERDESE2 in DDR = 10:1 over a 5× bit clock, so
  `serial_clk = 5 × pixel_clk`, identical to the Gowin OSER10 design. The encoder
  (`dvi_tmds_encoder`, latency 3, LSB-first 10-bit output) is reused as-is.
- **OSERDESE2 10:1 needs a master+slave cascade** (single OSERDESE2 maxes at 8:1). This
  is a standard Xilinx pattern — follow the Digilent rgb2dvi / XAPP example for the
  `SERDES_MODE="MASTER"/"SLAVE"` + `SHIFTIN/SHIFTOUT` wiring.
- **Bit order**: confirm OSERDESE2 shifts the 10-bit TMDS symbol in the order the
  encoder produces (LSB-first). A bit-order mismatch = scrambled/blank output (this is
  the Gowin-equivalent of the OSER10 phase gotcha).
- **I/O standard**: Arty Z7 HDMI TX is true differential TMDS on an HR bank — use the
  I/O standard Digilent's XDC specifies (typically `TMDS_33`), via `OBUFDS`. This is a
  *real* differential driver, unlike the Tang Nano's emulated `ELVDS_OBUF`.
- **PL-only is fine**: use the 125 MHz PL oscillator; no PS boot / Vitis needed for a
  free-running pattern generator. (Verify the Arty Z7 PL osc is usable without the PS;
  it is on this board.) Keep the option open to drive clocks from the PS later if needed.
- **Keep `rtl/reusable/**` vendor-neutral** — no `OSERDESE2`/`MMCME2`/`OBUFDS` outside
  `boards/artyz7/`. `make check` (Verilator + Yosys) must keep passing for the portable
  tree.
- **Constraints matter on Zynq**: `create_clock` for the 125 MHz osc; let the MMCM
  derive the rest; add `set_property` for the TMDS pins/IOSTANDARD; mind the serial
  clock placement (a BUFG/BUFIO/BUFR pattern for the OSERDESE2 fast clock — the
  Digilent reference shows the BUFIO+BUFR or BUFG_GT-free 7-series approach).
- **Button/reset polarity is opposite the Tang Nano**: Arty Z7 pushbuttons are
  **active-HIGH**, so instantiate `gpio_button_ctrl` with `.ACTIVE_LOW(1'b0)` and do NOT
  reuse the Tang Nano `resetn` naming. Map e.g. BTN0 = reset, BTN1 = pattern-advance;
  drive LEDs for `mmcm_locked` / `hpd_present` / pattern MSBs during bring-up.
- **Digilent IP is REFERENCE ONLY (hard rule + provenance)**: do NOT instantiate
  `rgb2dvi` in the validation top (that tests Digilent's encoder, not ours). Use its XDC,
  clocking, and OSERDESE2 wiring as a *reference* only. If any Digilent source is copied
  into `boards/artyz7/`, its license + provenance MUST be handled per `PROVENANCE.md`
  (and `make provenance` must still pass) — prefer writing our own thin wrappers.

## References (URLs verified by the Codex review)

- Digilent **Arty Z7** product page — confirms Z7-10/Z7-20, XC7Z020 on Z7-20, 85K LC /
  220 DSP / 4.9 Mb BRAM, HDMI sink+source, free Vivado:
  https://digilent.com/shop/arty-z7-zynq-7000-soc-development-board/
- Digilent **Arty-Z7-20 Master XDC** — `SYSCLK` H16 + HDMI TX pins/`TMDS_33`/`hdmi_tx_hpdn`:
  https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Arty-Z7-20-Master.xdc
- Arty Z7 **reference manual** — two unbuffered HDMI ports (source J11 / sink J10), TMDS,
  DDC/CEC/HPD sideband, **source HPD inverted on R19**:
  https://www.digikey.com/htmldatasheets/production/2076926/0/0/1/arty-z7-reference-manual.html
- Digilent **rgb2dvi** user guide — serializer/clocking reference; 1080p60 down to
  800×600p60; warns top-level clocks must be constrained and max can depend on `FMAX_BUFIO`:
  https://raw.githubusercontent.com/Digilent/vivado-library/master/ip/rgb2dvi/docs/rgb2dvi.pdf
- AMD **OSERDESE2** — `DATA_WIDTH` supports 10, `SERDES_MODE` master/slave:
  https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/OSERDESE2
- Xilinx **UG471** (7-series SelectIO / OSERDESE2), **UG472** (clocking / MMCM).
- This repo: `boards/tangnano9k/` is the working analogue (mirror its structure);
  `docs/porting.md` Recipe 3 is the generic new-board checklist; `CLAUDE.md` has the
  Gowin-side gotchas. Full review: `docs/codex-zynq-handover-review.md`.

## Open questions for the next session (decide early)

1. **Locate/source Vivado** (NOT on `PATH` in the review): `source <Vivado>/settings64.sh`;
   confirm the free tier covers `xc7z020clg400-1` (it does).
2. PL-only (125 MHz osc, no PS) vs minimal PS for clocks — default to **PL-only**.
3. Programming: `openFPGALoader -b arty_z7_20` (confirmed listed) vs Vivado/`xsct` — try
   openFPGALoader first (keeps the flow CLI/scriptable).
4. Run the **artifact-isolation ladder** (720p → 1024×768 → PANEL=12.3-nq1 → 1080p);
   `PANEL=` is in-scope early, not "later" — the Arty can natively drive the real panels
   (1920×720/40-LED, 2560×1440/47-LED), so this board is where custom timings get
   validated for real.
