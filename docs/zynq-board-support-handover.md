# Handover: add a Xilinx Zynq board (clean-HDMI RTL validation)

Date: 2026-06-09 · Status: **planning / not started** · For: the next Claude Code session.

This is a self-contained handover so a fresh session can add a second board to
`test-pattern-rtl` and continue without re-deriving context.

## Why we're doing this

On the Sipeed Tang Nano 9K (GW1NR-9C), HDMI is **emulated LVDS** (`ELVDS_OBUF`).
It's clean to ~325 MHz serial (480p/800×600/1024×768) but artifacts above that, and
even XGA (325 MHz, the ragged edge) has shown **placement-sensitive** lane dropouts
(recent symptom: a red right-third on solid white = green/blue lost in transmission;
720p shows green-tinted grid lines). We believe these are the **board's PHY at its
margin, not RTL bugs** — but we can't fully prove it on a board whose PHY is the
suspect. A board with a **real TMDS output path** (true differential serializer +
OBUFDS) that runs 720p/1080p cleanly will:

1. **Confirm the RTL is correct** — if the 32 patterns are clean at 720p/1080p on a
   real PHY, the Tang Nano artifacts are conclusively the ELVDS limit.
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
- `rtl/top_artyz7.sv` — top: 125 MHz PL osc → MMCM (pixel + 5× serial clock) →
  `video_source_core` → 3× `dvi_tmds_encoder` → 3× OSERDESE2 lanes + 1 clock lane →
  OBUFDS → HDMI TX. Button(s) for S2/S1-style pattern cycle/reset (reuse
  `rtl/control/gpio_button_ctrl.sv`).
- `rtl/artyz7_clkgen.sv` — MMCME2 wrapper: 125 MHz → `pixel_clk` + `serial_clk` (= 5×
  pixel). Same 5× ratio as the Gowin design (OSERDESE2 DDR does 10:1 over 5×), so the
  encoder/clocking contract is identical.
- `rtl/artyz7_tmds_lane.sv` — OSERDESE2 10:1 serializer (master+slave cascade) + OBUFDS
  for one differential pair. Drop-in analogue of `gowin_tmds_lane.sv` (OSER10).
- `constraints/artyz7.xdc` — HDMI TX pins (from Digilent's Arty Z7 master XDC), the
  125 MHz PL clock pin, I/O standards (TMDS_33 on the HR bank), and timing constraints
  (create_clock on the 125 MHz osc + the MMCM-derived clocks).
- `flow/build.tcl` — Vivado batch script (read sources + XDC, synth, impl, write
  bitstream). Keep the same knobs philosophy as `build.sh`: a `RES=` selecting the
  VMODE + MMCM divider settings; later a `PANEL=` reading `displays.conf`.
- `README.md` — board notes (like the Tang Nano one).

Resolution selection reuses `rtl/reusable/video/video_modes.svh` (the `VMODE_*` macros
are portable). Only the MMCM dividers (per pixel clock) are board-specific — analogous
to the rPLL dividers in the Tang Nano top.

## Bring-up plan (suggested order for the next session)

1. **Confirm hardware + tooling**: which Vivado version is installed; confirm the board
   variant (Arty Z7-**20**); locate Digilent's Arty Z7 **master XDC** + HDMI-out
   reference (rgb2dvi) for the exact TX pin names and I/O standard.
2. **Scaffold `boards/artyz7/`** (dirs above). Do NOT touch `rtl/reusable/**`.
3. **Clocking first**: `artyz7_clkgen.sv` (MMCM 125 MHz → 25.2 MHz pixel + 126 MHz
   serial for 480p). Get the MMCM to lock in sim/impl before anything else.
4. **One TMDS lane**: `artyz7_tmds_lane.sv` (OSERDESE2 10:1 cascade + OBUFDS). Verify the
   10-bit symbol shifts out LSB-first matching `dvi_tmds_encoder`'s bit order (this was a
   gotcha on Gowin — confirm OSERDESE2 bit order). Forward the pixel clock on the 4th
   (clock) lane, like the Tang Nano default.
5. **Wire the top** at 480p, build with Vivado batch, program, confirm color bars.
6. **Climb resolutions**: 720p (74.25 MHz pixel / 371.25 MHz serial) then 1080p
   (148.5 / 742.5). 7-series HR I/O + OSERDESE2 do 1080p in standard Digilent demos, but
   1080p is the most I/O-stressing — validate the OSERDESE2 cascade + OBUFDS there.
7. **Run the validation matrix** (below).

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

Decision rule:
- **Clean at 720p/1080p on the Arty** ⇒ the RTL is correct; the Tang Nano artifacts are
  conclusively its emulated-LVDS PHY. Document and move on (Tang Nano stays the
  low-cost ≤XGA board; Arty is the high-res / clean-reference board).
- **Same artifacts appear on the Arty** ⇒ a real RTL bug (encoder disparity/transition
  logic, VTG sideband alignment, or a pattern). Debug there — the OSS `make check` plus
  the clean PHY makes it tractable. Prime suspects to re-examine: `dvi_tmds_encoder`
  (8b/10b transition-min + running disparity), and channel/sideband alignment in
  `video_source_core`.

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

## References

- Digilent **Arty Z7** resource center (master XDC, HDMI-out reference design).
- Digilent **rgb2dvi** IP (github.com/Digilent/vivado-library) — reference for the
  OSERDESE2 10:1 cascade + TMDS clocking (use for the *serializer wiring*, but keep our
  own `dvi_tmds_encoder`).
- Xilinx **UG471** (7-series SelectIO / OSERDESE2), **UG472** (clocking / MMCM).
- This repo: `boards/tangnano9k/` is the working analogue — mirror its structure;
  `docs/porting.md` (Recipe 3) is the generic new-board checklist; `CLAUDE.md` has the
  Gowin-side gotchas for comparison.

## Open questions for the next session (decide early)

1. Vivado version available, and confirm free-tier covers the installed flow.
2. PL-only (125 MHz osc, no PS) vs minimal PS for clocks — default to **PL-only**.
3. Programming: `openFPGALoader -b arty_z7_20` vs Vivado/`xsct` — try openFPGALoader
   first (keeps the flow CLI/scriptable).
4. Target the validation at **720p first** (clean, lower I/O stress) before 1080p.
5. Reuse `displays.conf`/`PANEL=` later for the real panels (1920×720/40-LED etc.) —
   the Arty can actually drive those, so this board is also where the custom-timing
   panels get real validation.
