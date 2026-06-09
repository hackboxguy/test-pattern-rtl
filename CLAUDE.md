# CLAUDE.md — project context for Claude Code

Hardware-agnostic FPGA **display test-pattern generator**. A portable, vendor-neutral
RTL core (procedural patterns → RGB) wrapped in an open-source Gowin toolchain,
first target = Sipeed **Tang Nano 9K** (GW1NR-9C) over HDMI/DVI-TMDS.

**Status: Mode A implemented & hardware-validated.** Core is simulation-verified
with CI; on the Tang Nano 9K, **480p / 800×600 / 1024×768 (XGA) all run clean on
real HDMI**. Mode B (capture/genlock), AUTO fallback, and AXIS are interface stubs
for later milestones.

## Commands

```bash
# Portable gates (lint + Yosys-subset smoke + provenance + 9 self-checking sims)
make check            # or: make lint / make yosys-smoke / make provenance / make sim

# Tang Nano 9K bitstream (auto-activates OSS CAD Suite from ~/oss-cad-suite etc.)
RES=480p ./boards/tangnano9k/flow/build.sh           # default; also 800x600 / 1024x768 / 720rb / 1920x720 / 720p / 1080p
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
make report                                          # last build's timing + resource report (no rebuild)
```

Sims use Verilator `--binary`; the board flow needs **OSS CAD Suite** (modern
yosys + `nextpnr-himbaechel` + `gowin_pack`). `build.sh` auto-sources it.

## Layout (Tier 0–4 reusable model)

```
rtl/reusable/pattern/   Tier 0 — pattern_pixel_core + patterns/ (the portable core)
rtl/reusable/video/     Tier 1/2 — VTG, video_source_core, video_delay; Mode B stubs
rtl/reusable/{stream,cfg}/  Tier 3 — AXIS wrap (stub), cfg_cdc/cfg_regs/cfg_commit/cfg_pipe, reset_sync
rtl/control/            Tier 3 — gpio_button_ctrl (implemented)
boards/common/          dvi_tmds_encoder (generic DVI TMDS 8b/10b, 3-stage pipeline)
boards/tangnano9k/      Tier 4 — top + Gowin rPLL/CLKDIV/OSER10/ELVDS wrappers, .cst/.sdc, flow/build.sh
sim/                    Verilator self-checking testbenches
docs/                   PRD (design spec) + coding-standards + codex reviews (NOT committed)
```

## Hardware results (Tang Nano 9K) — the ELVDS cliff

| Resolution | serial rate | result |
|---|---|---|
| 640×480p60 / 800×600p60 / 1024×768p60 | ≤325 MHz | ✅ clean (all 32 patterns) |
| 1280×720p60 (any variant incl. reduced-blanking) | 324–371 MHz | ❌ marginal — colored lines at value transitions |
| 1920×1080p60 | 742.5 MHz | ❌ not buildable (rPLL CLKOUT caps at 600 MHz) |

**The artifacts are the board's emulated-LVDS PHY at its rate margin, NOT the RTL**
(R=G=B is emitted; lines are physical, at value transitions). 4:3 up to XGA is the
clean ceiling; native 16:9 needs reduced blanking, which starves the receiver's
per-line recovery at high rate. The same core runs higher on a true-LVDS board.

## Key decisions & gotchas (hard-won — read before changing the board path)

- **Toolchain: nextpnr-himbaechel is mandatory.** Classic `nextpnr-gowin` 0.6
  (Debian) cannot place `CLKDIV`; the CLKOUTD workaround mis-phases OSER10 → blank
  screen. Use OSS CAD Suite.
- **HDMI pins are EMULATED LVDS → `ELVDS_OBUF`** (not `TLVDS_OBUF`; nextpnr rejects
  TLVDS on pins 71/73/75/69). Each `*_p`/`*_n` net constrained to its own pin.
- **rPLL `DEVICE="GW1N-9C"`** for himbaechel (apicula PLL480 convention). Low PFD
  (high IDIV) hurts jitter at high serial rates — prefer `IDIV_SEL=0`.
- **Clocking:** 27 MHz → rPLL CLKOUT (5× pixel) → `CLKDIV(/5)` → pixel clock. TMDS
  clock channel = pixel clock forwarded to ELVDS by default; `-DSERIALIZE_TMDS_CLK`
  serializes it through a 4th OSER10 (didn't fix 720p — confirmed not clock-skew).
- **TMDS encoder is a 3-stage pipeline (latency 3)**, transition-min via parallel
  prefix-XOR. Needed to close 720p fabric timing.
- **SystemVerilog must pass `yosys read_verilog` too** (CI gate). yosys 0.33
  rejects `function automatic logic [N]` — encoder functions are Verilog-2001 style.
- **`PATSEL_W=5`** (32 patterns; was 4 → caused CASEOVERLAP/aliasing).
- **build.sh:** passes `--freq <pixel MHz>` (real timing target, not 12 MHz default)
  + post-build Fmax gate. Resolution is a compile-time macro (`-DBUILD_720P` etc.)
  + matching rPLL dividers in top.
- **P&R seed is PINNED by default (`NEXTPNR_SEED=2`).** A random seed (`-r`) made
  placement — and thus clock routing near the cliff — a lottery: an unlucky seed
  gives `serial_clk` a non-dedicated route ("Failed to route net 'serial_clk' …
  using dedicated routing") → a marginal clock the **monitor is slow to lock**
  onto (data is clean once locked). The build **fails** that condition for all
  high-rate modes (800x600/XGA/720rb/720p). Override `NEXTPNR_SEED=<n>` to sweep,
  `=r` for random. (Symptom if you see it: minute-long black screen before lock.)
- **1080p is physically impossible here** (742.5 MHz > rPLL 600 MHz max).
- **`PANEL=<name>` builds a named fixed-timing display** from `boards/tangnano9k/
  displays.conf` (transcribed subset of `docs/video-timings.md`): emits exact VTG
  timing defines (`VM_*`, consumed by the top's `PANEL_OVERRIDE` ifdef branch) and
  **solves the rPLL dividers** from the pixel clock (errors if >600 MHz CLKOUT;
  flags >325 MHz serial as over-cliff/EXPERIMENTAL). Only 12.3/12.3-nq1 are
  rPLL-buildable here; the rest need a faster board. `PANEL` not `DISPLAY` (X11).

## Pattern IDs (pattern_ids.svh, PAT_COUNT=32 — fills PATSEL_W=5 exactly)

`0` black · `1` white · `2` red · `3` green · `4` blue · `5–7` gray25/50/75 ·
`8` color_bars · `9` ramp_h · `10` ramp_v · `11` checker · `12` checker_1px ·
`13` grid · `14` staircase · `15–17` ramp_r/g/b (TMDS channel-isolation) ·
**`18–23` 2D local-dimming** (`pat_localdim`): window · moving window · zone
checker · near-black wedge · subtitle · flash · **`24–31` 1D edge-bar
local-dimming** (`pat_localdim_1d`): zone column · sweep · y-window · alt-zones ·
h-band · subtitle · flash · dual-highlight. Power-on = color_bars; **S2** cycles,
**S1** resets.

Both local-dimming families are sub-selected primitives reusing the ramp's
normalized coords + the frame counter — **zero extra multipliers**. The 1D family
(for bottom-edge LED-bar panels = vertical column zones) is parameterized by
**`LD1D_ZONES`** (LED count; `ZONES=<n>` build option, default 48); the per-pixel
zone index = `floor(norm_x*ZONES/2^COLOR_W)`. Target panels (`video_modes.svh`,
not Tang-Nano-buildable — need a faster board): `1920x720`/40-LED, `2560x1440`/47-LED.

## What's next (roadmap)

- **Mode B** (capture/genlock + frame insertion) and **AUTO** fallback — modules
  are stubs; recovered-clock topology with abrupt switch-over (PRD §8.7–8.8).
- **AXIS Video** wrapper (stub), CSR/UART/I²C control adapters (stub).
- Formal checks (SymbiYosys); ramp as a line-accumulator (Codex v2 #5, not done).
- A **true-LVDS / faster-serializer board** to get clean 720p/1080p (same RTL).

## Conventions

- Commit only when asked; work on `main` (user pushes). End commit messages with
  the `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.
- **Do NOT commit** `docs/codex-*.md` or `docs/*.jpg` (review artifacts / hardware
  photos) — they're kept untracked by convention. Build artifacts under
  `boards/*/build/` are gitignored.
- The **PRD (`docs/pattern-generator-rtl-prd.md`) is the design spec** and predates
  some as-built changes (14→32 patterns, PATSEL_W 4→5, the hardware findings). The
  **READMEs + this file are the as-built truth.**

## Pointers

- **Porting / add a custom timing or board:** [docs/porting.md](docs/porting.md)
  (add a panel = one row in `displays.conf`; new board = swap PLL/serializer/PHY/flow).
- Design spec: [docs/pattern-generator-rtl-prd.md](docs/pattern-generator-rtl-prd.md)
- Board details/experiments: [boards/tangnano9k/README.md](boards/tangnano9k/README.md)
- Coding standards: [docs/coding-standards.md](docs/coding-standards.md) ·
  Clean-room: [PROVENANCE.md](PROVENANCE.md)
