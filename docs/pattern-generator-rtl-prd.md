# Product Requirements Document — Display Test-Pattern Generator RTL Core

| | |
|---|---|
| **Document** | Display Test-Pattern Generator RTL Core — PRD |
| **Version** | 0.2.2 (Draft) |
| **Date** | 2026-06-07 |
| **Owner** | albert.david@gmail.com |
| **Status** | Design spec. **Mode A is implemented & hardware-validated** — for current as-built status see [`CLAUDE.md`](../CLAUDE.md) and [`boards/tangnano9k/README.md`](../boards/tangnano9k/README.md). Implementation evolved some details (18 patterns not 14; `PATSEL_W`=5; Tang Nano clean to 1024×768, 720p ELVDS-limited). |
| **License (target)** | MIT (LGPL/unlicensed HDL excluded from the portable tree by policy) |
| **Changes since v0.1** | Incorporates Codex PRD Reviews v1 & v2 (`docs/codex-prd-review-v1.md`, `docs/codex-prd-review-v2.md`); v0.2.1 de-scopes AUTO fallback to abrupt/low-priority; v0.2.2 adds the AUTO management-clock domain and tightens sideband/register/naming/provenance. See §23 Changelog. |

---

## 1. Overview

This document specifies the requirements for a **hardware-agnostic, synthesizable RTL core** that procedurally generates display test patterns (color bars, gradients, checkerboards, grids, solid fields, etc.) for validating displays of arbitrary resolution.

The reusable RTL is organized as **tiers** (§7.1). The smallest unit — a pure `(x, y, frame, config) → rgb` **pattern pixel core (Tier 0)** — can be dropped into other FPGA projects with a single directory copy and contains no vendor primitives. Device-specific logic (PLLs, TMDS/DVI serializers, I/O buffers, capture front-ends) lives in thin, swappable **board wrappers (Tier 4)** outside the portable tree.

The same pattern core supports these deployment modes:

- **Mode A — Master / Free-run.** The FPGA owns timing: an internal Video Timing Generator (VTG) produces a fixed, compile-time-selected VESA/CEA video timing and drives a display output (e.g. HDMI/DVI). First target: **Sipeed Tang Nano 9K** (no video capture front-end).
- **Mode B — Genlock / Insertion.** On boards that *capture* external video (HDMI / FPDLink / GMSL / eDP / LVDS), the design measures the incoming timing and **substitutes generated test-pattern frames for the source frames** on the **recovered source pixel clock**, preserving captured timing so the downstream panel sees valid frames.
- **AUTO — Genlock with internal fallback (low-priority/optional).** A runtime mode manager runs Mode B while a source is locked, and falls back to local free-running VTG + pattern generation when the source is disconnected or loses lock (so a panel keeps showing a known pattern). The transition is **abrupt** (a brief output blank / display re-sync is acceptable) — a smooth/glitchless switch is explicitly *not* required. See §8.8.

The supporting repository wraps the core in an open-source FPGA toolchain (Yosys + nextpnr + vendor bitstream tools), starting with the Tang Nano 9K and later porting to additional FPGA-based display hardware.

---

## 2. Goals and Non-Goals

### 2.1 Goals

1. **Hardware-agnostic core RTL** that synthesizes on Gowin, Xilinx, Lattice, and Altera/Intel parts without source changes — only the board wrapper changes.
2. **Single-copy portability** — the Tier 0 pattern directory copies into any repo against a documented interface.
3. **Resolution-independent** — patterns computed procedurally from pixel coordinates; no framebuffer, near-zero memory, scales to any resolution.
4. **One core; architecture provisions three timing models** — internal VTG (compile-time fixed) and external-capture genlock/insertion (recovered clock) are delivered first (M1/M4); AUTO fallback between them is **optional/roadmap**. The Tier 0 core is identical across all three.
5. **Pluggable control** — pattern/parameter selection comes from a separable adapter (GPIO button / I²C slave / UART / register bus) that is not part of the Tier 0 portability surface.
6. **Open-toolchain first** — buildable end-to-end with OSS CAD Suite (Yosys, nextpnr, apicula/trellis/prjxray), with the vendor toolchain (e.g. Gowin EDA) optional.
7. **First silicon on Tang Nano 9K** driving HDMI at a compile-time-fixed VESA/CEA resolution, pattern switching via the onboard button.
8. **Clean-room** — built from scratch; existing projects (Project F, hdl-util) used as behavioral/timing references only, never copied into the portable tree (§22).
9. **Verifiable** — simulation renders each pattern to an image for golden comparison; timing is self-checked (and formally checked) against the configured spec; config atomicity is tested. Fallback verification is **conditional** — required only when AUTO is in scope (§13).

### 2.2 Non-Goals (v1)

- No on-chip framebuffer, image decode, scaling, or video processing pipeline. (Mode B pure insertion needs no framebuffer; an elastic line buffer, if ever needed, is scoped *outside* Tier 0.)
- No HDMI audio, CEC, HDCP, or EDID emulation.
- No SoC/CPU softcore requirement (the optional register interface may attach to one, but the core does not depend on it).
- **`PIXELS_PER_CLOCK` > 1 is illegal in v1** — the multi-ppc lane ABI is *specified* now (§8.1) but only `PIXELS_PER_CLOCK = 1` is implemented until M5.
- No alpha-blended overlay in v1 (binary key/line overlay only; alpha deferred).
- Mode B / AUTO fallback are **architecturally provisioned in v1 but delivered in a later milestone** (§18). AUTO fallback is **low-priority/optional** and uses an **abrupt** switch-over (no glitchless transition).
- No guarantee of *bitstream*-toolchain maturity parity across all vendors (§15). The **RTL** is agnostic; the build flow is best-effort per target.

---

## 3. Background and Motivation

Bringing up and validating display panels and display-driver boards requires a reliable, known-good source of test frames. Off-the-shelf pattern generators are expensive and inflexible; a small, portable RTL core lets any FPGA-based display board become its own pattern source — standalone HDMI generator, inline frame-insertion block, or an internal fallback pattern when an external source disappears.

Portability is central: the same verified pattern logic should serve a $20 Tang Nano 9K demo *and* a production FPDLink/GMSL automotive display driver, differing only in the board wrapper.

---

## 4. Terminology

| Term | Meaning |
|---|---|
| **Tier 0 — Pattern Pixel Core** | The portable, vendor-neutral RTL mapping `(x, y, frame, config) → rgb`. No sync, no CDC, no bus, no PHY. |
| **Tier 1 — Video Source Core** | VTG + sideband alignment + pattern core → free-running Simple-Sync output. |
| **Tier 2 — Video Insert Core** | Captured-timing measurement, pattern substitution, overlay, AUTO mode manager. |
| **Tier 3 — Adapters** | AXI4-Stream Video, CSR/Wishbone-lite, I²C/UART/GPIO, config CDC. |
| **Tier 4 — Board Wrappers** | PLLs, serializers, I/O buffers, PHYs, constraints, board tops. Not portable. |
| **VTG** | Video Timing Generator. |
| **DE** | Data Enable — asserted during active (visible) pixels. |
| **SOF / EOL** | Start-of-Frame / End-of-Line one-cycle strobes. |
| **ppc / lane** | Pixels per clock; lane `i` carries pixel `x0 + i`. |
| **de_mask** | Per-lane valid bits for partial words at active-line edges. |
| **Genlock / Insertion** | Locking to an external source's timing / replacing its frames. |
| **AUTO / Fallback** | Runtime switch from external genlock to local VTG+pattern on source loss. |
| **CVT-RB** | VESA Coordinated Video Timings, Reduced Blanking. |
| **TMDS** | Transition-Minimized Differential Signaling (DVI/HDMI physical encoding). |

---

## 5. Users and Use Cases

| Persona | Need | Mode |
|---|---|---|
| **Hobbyist / maker** | Plug a Tang Nano 9K into a monitor, cycle patterns with a button. | A |
| **Display-driver HW engineer** | Drop the core in to validate panel timing/geometry/color during bring-up. | A / B |
| **Production test** | Insert known test frames inline to qualify panels on the line. | B |
| **Field robustness** *(roadmap/optional)* | Panel keeps showing a known pattern when the HDMI/FPDLink/GMSL/eDP/LVDS source is unplugged. | AUTO |
| **RTL integrator** | Instantiate with a register-mapped control interface and AXIS video pipeline. | A / B |

---

## 6. (reserved)

*Architecture is in §7 to keep numbering aligned with the tier model.*

---

## 7. System Architecture

### 7.1 Reusable RTL tiers

The reusable boundary is defined by **tiers**, so integrators copy only what they need. Tier 0 is the single smallest copyable unit.

| Tier | Module family | Responsibility | Copy/reuse status |
|---|---|---|---|
| **0** | `pattern_pixel_core` | Coordinates/geometry/config → RGB only. No sync, no CDC, no bus, no PHY. | **Minimum portable core.** |
| **1** | `video_source_core` | VTG + sideband alignment + pattern core → free-running Simple-Sync. | Reusable; not the pure core. |
| **2** | `video_insert_core` | Captured-timing measurement, substitution, overlay, AUTO mode manager. | Reusable for capture designs. |
| **3** | `stream_adapters` | AXI4-Stream Video, CSR/Wishbone-lite, I²C/UART/GPIO, config CDC. | Optional adapters. |
| **4** | `boards/*` | PLLs, serializers, I/O buffers, PHYs, constraints, board tops. | Not portable. |

**Design rule:** Tier 0 never generates sync and never instantiates a vendor primitive. It consumes a coordinate/DE stream and emits pixels. Everything device-specific is in Tier 4.

```
            ┌──────────────────────────────────────────────────────────────┐
            │ Tier 4  BOARD WRAPPER (per board, NOT portable)                │
            │   PLL/clocks · TMDS/DVI serializer · I/O buffers · capture PHY │
            │  ┌──────────────────────────────────────────────────────────┐ │
            │  │ Tier 1/2  REUSABLE VIDEO                                  │ │
            │  │   ┌─ Mode A: video_timing_gen ─┐                         │ │
            │  │   │ Mode B/AUTO: timing_measure │   timing_source_mux     │ │
            │  │   │   + video_mode_mgr          ├──►  + video_delay       │ │
            │  │   └─────────────────────────────┘        │                │ │
            │  │            x,y,de,frame,config ──►┌───────▼────────┐       │ │
            │  │  ┌──────────────────────────────┐│ Tier 0          │       │ │
            │  │  │ Tier 3 cfg_cdc / cfg_regs    ││ pattern_pixel_  │──rgb─►│ │
            │  │  │  ◄─ GPIO/I2C/UART/CSR        ││ core            │       │ │
            │  │  └──────────────────────────────┘└─────────────────┘       │ │
            │  │   insertion_mux ──► Simple-Sync (+ optional AXIS adapter)  │ │
            │  └──────────────────────────────────────────────────────────┘ │
            └──────────────────────────────────────────────────────────────┘
```

### 7.2 Operating modes

**Mode A — Master / Free-run (Tang Nano 9K target).** Internal VTG generates H/V timing for a **compile-time-fixed** resolution (`RESOLUTION` make flag). Tier 0 fills active pixels; the output stage drives HDMI/DVI via the Tier 4 wrapper. Pattern selection from a pluggable adapter (Tang Nano: onboard debounced button).

**Mode B — Genlock / Insertion (recovered-clock, later milestone).** A capture front-end (Tier 4) recovers pixel clock + sync + DE (+ optional source RGB). `timing_measure` reports lock + measured geometry. The whole insertion path — including Tier 0 — is clocked by the **recovered source pixel clock**. `insertion_mux` replaces source active pixels with generated pixels on frame boundaries while preserving captured timing (no framebuffer for pure insertion). Resolution follows the measured source at runtime.

**AUTO — Genlock with internal fallback (low-priority/optional).** `video_mode_mgr` runs Mode B while locked and switches to local VTG + pattern when the source is lost. Because the reference Mode B topology is recovered-clock-end-to-end, the output clock must change from the recovered pixel clock to the local PLL clock on fallback. Per owner direction, this is an **abrupt, reset-based switch** — *not* a glitchless transition — so it needs **no glitch-free clock-mux primitive and no live link retrain**; a brief output blank / display re-sync is acceptable (§8.8). This keeps the feature cheap enough to remain in scope as an optional M4 item.

The Tier 0 pattern core is **identical** across all modes; only its timing/coordinate source, the output mux, and the clock strategy differ.

---

## 8. Functional Requirements

### 8.1 Pattern Pixel Core (Tier 0) — FR-CORE

- **FR-CORE-1** SHALL compute each pixel's color as a function of `(x, y, frame, active_config)` and `de`, with no framebuffer.
- **FR-CORE-2** SHALL be pure synthesizable RTL: no vendor primitives, no PLL, no gated clocks, no CDC, and no large inferred memory for v1 patterns.
- **FR-CORE-3 (ppc ABI, locked now; ppc=1 enforced in v1)** The interface SHALL define multi-pixel-per-clock semantics even though v1 implements only `PIXELS_PER_CLOCK = 1`:
  - Lane `i` carries the pixel at column `x0 + i` (horizontal packing); `x0` is the lane-0 column.
  - `de_mask[PIXELS_PER_CLOCK-1:0]` marks valid lanes; partial words at the right edge of an active line are representable (`H_ACTIVE % PIXELS_PER_CLOCK != 0`).
  - **RGB packing:** lane 0 occupies the LSBs; within a lane the order is `{R, G, B}` from MSB→LSB, each `COLOR_W` wide.
  - `sof`, `eol`, `hsync`, `vsync` are **word-level** sideband (one per clock, not per lane); `x0` is the lane-0 coordinate of that word. `eol` asserts on the **word containing the final active pixel**, with `de_mask` identifying the final valid lane.
  - For v1, `PIXELS_PER_CLOCK` MUST be 1 and `de_mask` is a single bit equal to `de`. Synthesizing with `PIXELS_PER_CLOCK > 1` is an explicit error until M5.
- **FR-CORE-4 (fixed latency; Tier 0 emits pixels only)** Tier 0 SHALL have a fixed, documented `PATTERN_LATENCY` and SHALL output **only** `rgb` + `de_mask_out` — it does **not** emit aligned sideband or a Simple-Sync stream. The Tier 1/2 wrapper owns full sideband alignment via `video_delay` (§8.5).
- **FR-CORE-5** A pattern/param change SHALL take effect atomically on a frame boundary per the config contract (§8.6) — never mid-frame, never half-updated.
- **FR-CORE-6 (synthesis-safe math)** Pattern math SHALL avoid runtime division/modulo in the pixel datapath:
  - Checkerboard/blocks default to **power-of-two** sizes (shifts/masks). `ALLOW_RUNTIME_DIV` (default 0) gates any non-pow2 path.
  - Arbitrary grid pitch uses **counters that reset at the pitch**, not `% pitch`.
  - Gradients use **accumulator/Bresenham-style stepping** or precomputed reciprocals, not wide runtime division in the hot path.
  - Each pattern documents its resource profile (mult/add/cmp/RAM/DSP) and latency; CI enforces a per-pattern synthesis budget (§13).

### 8.2 Initial pattern set (v1) — FR-PAT

All are pure coordinate functions:

1. **Solid fields** — black, white, red, green, blue, 25/50/75% gray.
2. **Color bars** — full-amplitude (100%) vertical RGB bars: white/yellow/cyan/green/magenta/red/blue. Documented as **approximate**, *not* PLUGE/IRE-exact (exact SMPTE 75% + PLUGE deferred — §9).
3. **Gradients / ramps** — horizontal and vertical luminance ramps (banding, gamma), accumulator-based.
4. **Checkerboard** — power-of-two block size, plus **1-pixel checkerboard** (pixel-clock integrity).
5. **Grid / crosshatch** — counter-reset pitch, single-pixel lines (geometry, convergence).

**Roadmap patterns** (later): grayscale staircase, multiburst/frequency sweep, moving/scrolling bars, border/overscan frame, PRBS field, zone plate, moving box, stuck-pixel.

### 8.3 Pattern ID and parameter ABI — FR-ABI

- **FR-ABI-1** Pattern IDs SHALL be **stable across builds**; disabling a pattern does **not** renumber others.
- **FR-ABI-2** A **disabled** pattern ID SHALL output a documented fallback (black), not a shifted-ID alias.
- **FR-ABI-3** Out-of-range parameter writes SHALL **clamp** to the valid range (and set a sticky `param_clamped` status bit).
- **FR-ABI-4** A read-only `PATTERN_ABI_VERSION` and an `ENABLED_PATTERNS` mask SHALL be exposed so integrators can discover the library.

Initial ID table (illustrative; finalized in M1):

| ID | Name | Params | Defaults | Constraints | Mask bit |
|---|---|---|---|---|---|
| 0 | black | — | — | always | 0 |
| 1 | white | — | — | always | 1 |
| 2 | red / 3 green / 4 blue | — | — | always | 2–4 |
| 5–7 | gray25/50/75 | — | — | always | 5–7 |
| 8 | color_bars | — | — | always | 8 |
| 9 | ramp_h / 10 ramp_v | — | — | always | 9–10 |
| 11 | checker | block_log2 | 4 | 0..max | 11 |
| 12 | checker_1px | — | — | always | 12 |
| 13 | grid | pitch, line_w, color | 32, 1, white | pitch≥2 | 13 |

### 8.4 Video Timing Generator (Tier 1) — FR-VTG

- **FR-VTG-1** Generates hsync, vsync, DE, active `(x, y)`, a free-running `frame` counter, and `sof`/`eol` strobes for the configured resolution.
- **FR-VTG-2** Sync polarities parameterized per the VESA/CEA spec for the selected mode.
- **FR-VTG-3** Timing comes from a **resolution table** keyed by `RESOLUTION`, with explicit `standard_family` and `vic` fields per entry (`vic=0`/none for DMT/CVT). At least: `640x480p60` (VGA/DMT, HDMI VIC 1), `1280x720p60` (VIC 4), `1920x1080p60` (VIC 16). Use **full mode names** everywhere, never bare `480p60`. CVT-RB variants supported where they reduce pixel clock (with the §9 caveat).
- **FR-VTG-4** Distinguishes 60.000 Hz from 59.94 Hz variants; the default modes use exact 60.000 Hz with the §11 pixel clocks.

### 8.5 Coordinate and sideband semantics — FR-SB

- **FR-SB-1** `(x, y) = (0, 0)` at the **first active pixel** of each frame; `x` increments per active pixel and resets each active line; `y` increments per active line and resets each frame.
- **FR-SB-2** `x`/`y` are valid only when `de = 1`; during blanking they hold and MUST be gated on `de` by consumers.
- **FR-SB-3** `rgb` during blanking SHALL be 0 (black) unless a pattern documents otherwise.
- **FR-SB-4** `sof` is a **one-cycle pulse on the first active pixel** of the frame (active-based, not blanking-based). `eol` is a one-cycle pulse on the **word containing the last active pixel** of each line (for ppc>1, `de_mask` marks the final valid lane).
- **FR-SB-5 (alignment lives in Tier 1/2, not Tier 0)** A reusable `video_delay` in the Tier 1/2 wrapper SHALL delay `de, de_mask, hsync, vsync, sof, eol, x0, y, frame` by exactly `PATTERN_LATENCY` so all sideband stays aligned to `rgb` at the **wrapper** output. Tier 0 itself only guarantees `rgb`/`de_mask_out` at fixed latency (FR-CORE-4).

### 8.6 Runtime configuration contract — FR-CFG

- **FR-CFG-1** Config (pattern_sel + all params) is held in **shadow registers** in the control clock domain.
- **FR-CFG-2** A dedicated `cfg_cdc` block crosses the shadow bundle into the pixel clock domain with a handshake (no bit-tearing).
- **FR-CFG-3** `active_config` is latched **only on `sof`**, so `pattern_sel` and every param update **atomically** on the same frame boundary.
- **FR-CFG-4** Status SHALL expose `cfg_pending` (staged, not yet applied), a `cfg_applied` pulse, and `applied_frame`/`cfg_epoch`. Integrators MUST be able to confirm which frame a config took effect on.
- **FR-CFG-5** Disabled-pattern behavior follows FR-ABI-2 (stable IDs, black fallback).

### 8.7 External capture / genlock-insertion (Tier 2) — FR-CAP (later milestone)

- **FR-CAP-1** Accepts recovered pixel clock + hsync + vsync + DE (+ optional source RGB) from a Tier 4 capture front-end. The insertion path (incl. Tier 0) runs on the **recovered source pixel clock**.
- **FR-CAP-2** `timing_measure` SHALL measure and report: active width/height, H/V totals, sync widths, polarities, interlace flag, frame-rate estimate, and `locked`.
- **FR-CAP-3** Lock acquisition requires **N consecutive stable lines/frames** within tolerance windows; unlock criteria and hysteresis/debounce are defined so marginal cables do not flap the output.
- **FR-CAP-4** `insertion_mux` replaces source active pixels with generated pixels on frame boundaries while preserving captured timing.
- **FR-CAP-5 (insert sub-mode, v1 = binary overlay)** Insertion behavior is selected by `INSERT_MODE ∈ {REPLACE, OVERLAY, PASSTHROUGH}` — a sub-mode **separate from `TIMING_MODE`**. `OVERLAY` in v1 is **binary key/line only** (e.g. grid/crosshair over live video); alpha blending is deferred (needs source RGB blend + more logic).
- **FR-CAP-6** Loss-of-lock behavior is defined **separately** for generator-only, insertion, and overlay modes (default: enter AUTO fallback per §8.8; otherwise blank or hold last frame, configurable).

### 8.8 AUTO mode manager and fallback (Tier 2) — FR-AUTO (later milestone, LOW PRIORITY / optional)

> **Priority note (owner direction, v0.2.1):** AUTO fallback is optional and may be deferred or dropped without affecting Mode A or pure Mode B. The transition is **abrupt** — a brief output blank / display re-sync is acceptable; a glitchless transition is *not* a requirement.

- **FR-AUTO-1** `TIMING_MODE` SHALL support `INTERNAL`, `EXTERNAL`, and (optionally) `AUTO`. In `AUTO`, `video_mode_mgr` selects between captured timing/coords/RGB and local VTG timing/coords + pattern RGB.
- **FR-AUTO-2** State machine SHALL include at least: `INTERNAL_FREE_RUN`, `EXT_LOCKING`, `EXT_LOCKED_INSERT`, `EXT_LOCK_LOST`, `FALLBACK_INTERNAL`. Transitions occur at a safe frame boundary / defined blanking window where practical; an abrupt transition is acceptable.
- **FR-AUTO-3** On source disconnect in `AUTO`, the design SHALL switch to local VTG + internal pattern within a **bounded number of frames**.
- **FR-AUTO-4 (abrupt switch-over accepted)** A smooth/glitchless transition is **NOT required**. Fallback MAY use a simple **reset-based clock-source change**: hold the output PHY in reset/blank, switch the output clock from the recovered pixel clock to the local PLL clock (clock glitches during the switch are acceptable while the PHY is held in reset), then release reset and bring up the local VTG. This **removes the need for a glitch-free clock-mux primitive and for FPGA-side protocol link-retrain logic**. Note: the FPGA does not run protocol-level retrain, but the **sink will still re-synchronize** to the changed clock — so the Tier 4 wrapper SHALL hold the output in reset/blank across the switch and tolerate the monitor/panel re-lock time. A brief output blank / display re-sync is acceptable. The local PLL MAY be kept always-on to simplify the switch.
- **FR-AUTO-5** `FALLBACK_RESOLUTION` (default `1280x720p60`, a known-safe mode) is configurable independently of the last measured source; an option MAY reuse the last locked geometry when the local PLL can generate it.
- **FR-AUTO-6** `RELOCK_POLICY` SHALL select whether source reconnect **auto-returns** to genlock after N consecutive stable frames or **stays in fallback until commanded**.
- **FR-AUTO-7** Status SHALL expose `source_present`, `cap_locked`, `active_timing_source`, `fallback_active`, `fallback_reason`, `lock_lost_count`.
- **FR-AUTO-8** The Tier 0 pattern core SHALL be identical across both timing sources; only the timing-source mux and (abrupt) clock strategy change.

**8.8.1 AUTO clock/control domains — FR-AUTO-CLK.** The recovered source pixel clock may **stop or go invalid** when the source is unplugged — so the supervisor that must detect loss and command fallback **cannot** be clocked by it (otherwise it stalls exactly when needed).

- **FR-AUTO-CLK-1** When AUTO is in scope, the design SHALL provide an **always-on management clock** (`mgmt_clk` — an on-board oscillator or local-PLL-derived clock that never depends on the source). `video_mode_mgr`, source-present debounce, lock-loss timers, relock policy, and clock-source/reset control run in this domain.
- **FR-AUTO-CLK-2** The recovered pixel clock is a **data-plane** clock only, never the sole control-plane clock.
- **FR-AUTO-CLK-3** The design SHALL expose clock/reset handshakes: `src_pixclk_valid`, `local_pixclk_valid`, `out_video_rst_req`, `out_video_rst_done`, `active_clock_source`, `timing_source_valid`.
- **FR-AUTO-CLK-4** CDC boundaries between `mgmt_clk`, the recovered pixel clock, and the local pixel clock SHALL be defined and isolated in named CDC modules (§15).
- **FR-AUTO-CLK-5** The available `mgmt_clk` source is board-specific and is an owner/HW decision for the Mode B reference board (§19).

### 8.9 Control / selection (Tier 3, pluggable) — FR-CTRL

- **FR-CTRL-1** Tier 0 exposes a minimal selection bundle (`pattern_sel`, `param[]`, `enable`). The *source* of these values is a separate adapter and is **not** part of Tier 0's portability contract.
- **FR-CTRL-2** Provided adapters: **GPIO button** (debounced, cycles `pattern_sel`; Tang Nano), **UART** command protocol, **I²C slave** register map, **CSR/Wishbone-lite** register map.
- **FR-CTRL-3** Adapters write shadow registers; the config contract (§8.6) handles CDC and frame-boundary commit.

### 8.10 Output interface — FR-OUT

- **FR-OUT-1 (real-time, non-backpressurable)** The native **Simple-Sync** interface `{rgb, de, hsync, vsync, sof, eol, x, y, frame}` is a free-running real-time stream: pixels are produced every active cycle and MUST be consumed; there is no backpressure.
- **FR-OUT-2 (AXIS is an adapter, not the PHY path)** The optional **AXI4-Stream Video** wrapper maps the native stream to `tdata=rgb, tvalid, tready, tuser[0]=SOF, tlast=EOL` for SoC/sim use. Its stall policy SHALL be explicit and one of: (a) **source-only, `tready` required high during active video** (deassertion during active video sets `err_tready_low`), or (b) **FIFO-buffered with bounded underflow/overflow** and `err_underflow`/`err_overflow` flags. The AXIS wrapper is **not** the real-time display PHY interface.
- **FR-OUT-3 (Mode B never stalls captured timing)** On downstream backpressure in Mode B, the design SHALL NOT stall captured timing; it chooses pass-through, blank, drop-overlay, or assert error — configurable, defaulting to pass-through.
- **FR-OUT-4** TMDS/DVI encoding and serialization are **Tier 4** responsibilities and SHALL NOT appear in the portable tree.

---

## 9. Color, Range, and Timing Precision — FR-CLR

- **FR-CLR-1** RGB channel order and packing are fixed per §8.1 (`{R, G, B}` MSB→LSB per lane; lane 0 in LSBs).
- **FR-CLR-2** `RGB_RANGE` selects **full-range** (default, `0..2^COLOR_W-1`) or **limited-range** (e.g. 16..235 @8b). Note: many HDMI/CEA TVs assume limited range; PC monitors assume full range — the choice is explicit, not implied.
- **FR-CLR-3** Canonical 8-bit pattern values scale to `COLOR_W ∈ {8,10,12,16}` by **MSB-justification with bit-replication** (documented formula).
- **FR-CLR-4** v1 color bars are **approximate full-amplitude RGB bars**, not standards-exact. Exact SMPTE (75% bars + PLUGE/IRE) is a later, explicitly-specified pattern.
- **FR-CLR-5** Modes use **full names** everywhere (`640x480p60`, `720x480p60`, `1280x720p60`, `1920x1080p60` — never bare `480p60`, which is ambiguous with 720x480) and carry explicit `standard_family` + `vic` fields (`640x480p60`→VGA/DMT, also HDMI VIC 1; `1280x720p60`→VIC 4; `1920x1080p60`→VIC 16; `vic=0`/none for pure DMT/CVT), distinguishing 60.000 from 59.94 Hz.
- **FR-CLR-6** Prefer **standard CEA timings** for 720p/1080p; **CVT-RB** is a clock-reduction fallback only where a sink accepts it (many HDMI displays are more reliable with CEA than RB).

---

## 10. Interface Specification (core boundary)

**Source language (decision):** ergonomic **SystemVerilog, Yosys-tested subset** (`logic`, `int` params, packed/unpacked arrays where Yosys+Verilator accept them). CI proves the subset against the **per-milestone supported-target matrix** (§12); a construct rejected by a **currently-supported** target is a blocking bug. Targets not yet in the matrix (e.g. Xilinx/Intel early on) remain portability *goals*, not gates.

### 10.1 Pattern Pixel Core (Tier 0)

```systemverilog
module pattern_pixel_core #(
    parameter int COLOR_W          = 8,     // bits/channel (RGB888 -> 8)
    parameter int PIXELS_PER_CLOCK = 1,     // MUST be 1 in v1 (ABI defined for >1)
    parameter int HCOORD_W         = 12,
    parameter int VCOORD_W         = 12,
    parameter int FRAME_W          = 24,
    parameter int PATSEL_W         = 4,
    parameter int NPARAM           = 4,
    parameter int PARAM_W          = 32
)(
    input  logic                                  clk,
    input  logic                                  rst,        // active-high, synchronous
    // timing / coordinate stream (from VTG or capture); lane 0 = x0
    input  logic                                  de,
    input  logic [PIXELS_PER_CLOCK-1:0]           de_mask,    // == de when ppc==1
    input  logic [HCOORD_W-1:0]                   x0,
    input  logic [VCOORD_W-1:0]                   y,
    input  logic [FRAME_W-1:0]                     frame,
    input  logic                                  sof,
    input  logic                                  eol,
    // active geometry (constant in Mode A, measured in Mode B)
    input  logic [HCOORD_W-1:0]                   h_active,
    input  logic [VCOORD_W-1:0]                   v_active,
    // active_config (already CDC'd and frame-latched upstream by cfg_cdc)
    input  logic                                  pat_en,
    input  logic [PATSEL_W-1:0]                   pattern_sel,
    input  logic [NPARAM*PARAM_W-1:0]             param,      // packed lane order documented
    // pixel output ONLY (fixed PATTERN_LATENCY); sideband alignment owned by Tier 1/2
    output logic [PIXELS_PER_CLOCK*3*COLOR_W-1:0] rgb,        // {R,G,B} MSB->LSB per lane
    output logic [PIXELS_PER_CLOCK-1:0]           de_mask_out
);
```

> **Tier 0 boundary:** `pattern_pixel_core` exposes a fixed `PATTERN_LATENCY` (localparam) and emits **only** `rgb`/`de_mask_out`. The Tier 1/2 wrapper delays all sideband (`hsync/vsync/sof/eol/x0/y/frame/de`) by `PATTERN_LATENCY` via `video_delay` and produces the aligned Simple-Sync stream (§8.5). Tier 0 does not import `hsync/vsync/sof/eol` as outputs.

### 10.2 Simple-Sync output (Tier 1)

`clk, rst, hsync, vsync, de, rgb[..], sof, eol, x0, y, frame` — free-running, non-backpressurable. Polarities via `HSYNC_POL`, `VSYNC_POL`.

### 10.3 AXI4-Stream Video adapter (Tier 3)

`m_axis_tdata = rgb`, `m_axis_tvalid`, `m_axis_tready`, `m_axis_tuser[0] = SOF`, `m_axis_tlast = EOL`, plus the explicit stall policy + error flags from FR-OUT-2. Adapter/sim use only — not the PHY path.

### 10.4 Control / status register map (Tier 3)

| Offset | Name | Access | Description |
|---|---|---|---|
| 0x00 | `CTRL` | RW | `[0]` enable, `[1]` soft-reset, `[3:2]` `TIMING_MODE` (INTERNAL/EXTERNAL/AUTO), `[5:4]` `INSERT_MODE` (REPLACE/OVERLAY/PASSTHROUGH) |
| 0x04 | `PATTERN_SEL` | RW | **Shadow** pattern index (commits on next `sof`); reads return the staged shadow value |
| 0x08 | `ACTIVE_PATTERN_SEL` | RO | Currently **active** (committed) pattern index |
| 0x0C | `STATUS` | RO | `source_present`, `cap_locked`, `active_timing_source`, `active_clock_source`, `fallback_active`, `cfg_pending`, `param_clamped` |
| 0x10 | `H_ACTIVE` | RO/RW | Measured (Mode B) or override |
| 0x14 | `V_ACTIVE` | RO/RW | Measured (Mode B) or override |
| 0x18 | `FRAME_COUNT` | RO | Free-running frame counter |
| 0x1C | `APPLIED_FRAME` | RO | Frame index the active config took effect on (`cfg_epoch`) |
| 0x20 | `ABI_VERSION` | RO | `PATTERN_ABI_VERSION` |
| 0x24 | `ENABLED_PATTERNS_LO` | RO | Enabled-pattern mask bits `[31:0]` |
| 0x28 | `ENABLED_PATTERNS_HI` | RO | Enabled-pattern mask bits `[63:32]` (extend the range as the library grows) |
| 0x2C | `FALLBACK_CFG` | RW | `RELOCK_POLICY`, `FALLBACK_RESOLUTION` selector |
| 0x30 | `FALLBACK_STATUS` | RO | `fallback_reason`, `lock_lost_count` |
| 0x40.. | `PARAM[n]` | RW | **Shadow** pattern params (clamped; commit on `sof`) |
| 0x80.. | `ACTIVE_PARAM[n]` | RO | Currently **active** (committed) params |

**Readback semantics:** `PATTERN_SEL`/`PARAM[n]` are shadow registers — writes stage, reads return the staged value; the committed config is exposed read-only via `ACTIVE_PATTERN_SEL`/`ACTIVE_PARAM[n]` and `APPLIED_FRAME`. Fallback **policy** (`FALLBACK_CFG`) and fallback **status** (`FALLBACK_STATUS`) are separate registers. The enabled-pattern mask spans `_LO`/`_HI` (extendable) so it scales past 32 patterns.

---

## 11. Target Platform — Sipeed Tang Nano 9K (Mode A, first board)

- **FPGA:** Gowin GW1NR-9C (LittleBee), ~8.6k LUT4, BSRAM, on-package PSRAM, `rPLL`.
- **Display out (Tier 4):** HDMI driven as **DVI/TMDS**: `rPLL` → 5× serial clock; `CLKDIV` (÷5) → pixel clock; DVI 8b/10b TMDS encoders → `OSER10` 10:1 serializers → `TLVDS_OBUF` differential outputs for 3 data + 1 clock pairs. *(Confirm the exact primitive recipe against current Gowin docs at board scaffolding — see §22.)*
- **Control:** onboard user button → debounce adapter → `pattern_sel` cycling.
- **Compile-time resolution:** fixed via `RESOLUTION` (target `1920x1080p60`).

**1080p60 clocking (made explicit per Codex §9):** 1080p60 RGB888 TMDS needs **148.5 MHz pixel clock, 742.5 MHz 5× DDR serializer clock, 1.485 Gb/s per lane**. This is aggressive for the GW1NR-9 on the open flow. Mitigations: (a) **bring-up ladder 640×480p60 → 1280×720p60 → 1920×1080p60**; (b) prefer standard **CEA** timing (CVT-RB only if the sink accepts it); (c) **720p60 is the must-pass milestone**, 1080p60 the stretch target.

---

## 12. Toolchain and Build System

**Primary (open):** Yosys (synth); nextpnr — `nextpnr-himbaechel` (Gowin/**apicula**), `nextpnr-ecp5`/`nextpnr-ice40` (Lattice/**Trellis**/**IceStorm**), `nextpnr-xilinx` (**prjxray**, experimental), Project Mistral (Altera Cyclone V, experimental); bitstream via `gowin_pack`/`ecppack`/`icepack`/prjxray. Packaged via **OSS CAD Suite**.

**Alternative (vendor):** Gowin EDA (and respective vendor tools per part), selectable by a build switch.

**Constraints:** per-board `.cst`/`.lpf`/`.xdc` + `.sdc` in `boards/<board>/`, never in the portable tree.

**SV-subset gate (per-milestone matrix):** CI runs a synth-smoke against a **versioned supported-target matrix**, not every vendor from day one. Initial matrix: **Gowin (M1–M2)**, **+ one Lattice family (M3)**; Xilinx 7-series and Intel/Altera stay portability goals until added to the matrix. A construct rejected by a *currently-supported* target is a blocking bug; rejection by an out-of-matrix target is tracked, not blocking. A generated Verilog-2001/`sv2v` release artifact MAY be added later if broad vendor import becomes painful.

**Bitstream maturity (honesty):** the **RTL** is vendor-agnostic; the **bitstream** flow maturity differs (Gowin/Lattice strong; Xilinx 7-series and Altera experimental on the open flow). Per-target status is documented in the build system.

---

## 13. Verification and Validation

- **Lint:** `verilator --lint-only -Wall` + `yosys read` smoke for each target on every push.
- **Simulation:** cocotb (preferred) or SV testbenches on Verilator/Icarus.
- **Procedural frame dump:** each pattern rendered to **PPM/PNG**, golden-compared in CI — including at least one **odd geometry** (e.g. 13×7, 101×53), not only standard modes.
- **Formal:** checks for VTG line/frame counters, sync widths, `sof`/`eol` correctness, and **no mid-frame config application**.
- **Config atomicity tests:** update `pattern_sel`/params mid-frame; verify the old config stays active until the next `sof`, and `applied_frame` reports correctly.
- **Boundary/randomized tests:** non-divisible active widths, unusual small resolutions, param boundary/clamp behavior, disabled pattern IDs (must return black, not renumber).
- **ppc tests:** required *before* any claim that `PIXELS_PER_CLOCK > 1` works (gated to M5).
- **AXIS adapter tests:** `tready` stalls, underflow, overflow, and the selected stall policy.
- **Mode B / AUTO tests (conditional — only when AUTO is in scope):** source-present → source-lost → local VTG fallback within bound; **reset-based clock-source switch** with an output blanking/re-sync window; bounded-time fallback; marginal-lock flapping with hysteresis; relock policy; and that the **`mgmt_clk` supervisor keeps running when the recovered clock stops** (FR-AUTO-CLK).
- **License/provenance check:** CI asserts no LGPL/unlicensed sources entered the portable tree (clean-room policy, §22).
- **Per-pattern synthesis budget:** CI tracks LUT/DSP/BRAM per enabled pattern set to catch regressions (§8.1 FR-CORE-6).

---

## 14. Repository Structure

```
.
├── docs/
│   ├── pattern-generator-rtl-prd.md      # this document
│   ├── codex-prd-review-v1.md            # incorporated review
│   └── codex-prd-review-v2.md            # incorporated review
├── rtl/
│   ├── reusable/                         # PORTABLE (tiers 0–3)
│   │   ├── pattern/                       # Tier 0 — smallest copyable unit
│   │   │   ├── pattern_pixel_core.sv
│   │   │   ├── pattern_ids.svh
│   │   │   └── patterns/                  # one file per pattern
│   │   ├── video/                         # Tier 1/2
│   │   │   ├── video_timing_gen.sv
│   │   │   ├── video_delay.sv
│   │   │   ├── timing_measure.sv
│   │   │   ├── timing_source_mux.sv
│   │   │   ├── video_mode_mgr.sv
│   │   │   └── insertion_mux.sv
│   │   ├── stream/                        # Tier 3
│   │   │   └── axis_video_wrap.sv
│   │   └── cfg/                           # Tier 3
│   │       ├── cfg_cdc.sv
│   │       ├── cfg_regs.sv
│   │       └── reset_sync.sv
│   └── control/                          # GPIO/UART/I2C/CSR adapters
├── boards/
│   └── tangnano9k/                        # Tier 4: PLL, TMDS PHY, .cst, .sdc, top
├── sim/                                   # cocotb tests, golden images, harness
├── flow/                                  # make/scripts: open + vendor flows
├── third_party/                           # any vendored permissive code (OUTSIDE rtl/reusable/), license headers preserved
├── PROVENANCE.md                          # clean-room/provenance procedure + external-reference log (§20)
├── LICENSE                                # MIT
└── README.md
```

This preserves the "single directory copy" goal: `rtl/reusable/pattern/` is the minimum unit, and integrators pull higher tiers only as needed.

---

## 15. RTL Coding Standards (summary)

- SystemVerilog, **Yosys-tested subset**; **CI proves it against the per-milestone supported-target matrix** (§12). No vendor attributes/primitives in the portable tree.
- **Reset convention:** portable RTL uses **active-high synchronous `rst`**; Tier 4 board wrappers convert external reset polarity. (Replaces v0.1's per-core reset-polarity parameter.)
- **CDC isolation:** all CDC lives in named modules — `cfg_cdc`, `pulse_cdc`, `reset_sync`. Pattern math contains no CDC.
- Synchronous design, single core clock domain per instance; no latches, no gated clocks.
- One pattern per file with a uniform signature for easy extension; stable pattern IDs (§8.3).
- Tier 0 has a fixed `PATTERN_LATENCY` and emits pixels only; sideband alignment via `video_delay` lives in the Tier 1/2 wrapper (§8.5).
- Lint-clean (`-Wall`) is a merge gate.

---

## 16. Resource and Performance Budget (targets)

| Block | Budget (ppc=1, RGB888) |
|---|---|
| Tier 0 pattern core (v1 set) | small (low-hundreds of LUT4, **0 BRAM**) |
| VTG | small counters + comparators |
| TMDS/serializer (Tier 4) | board cost, not core |
| `Fmax` | ≥ pixel clock of target resolution (148.5 MHz @1080p60) |

Per-pattern budgets are tracked in CI (§13).

---

## 17. Milestones / Phasing

| Milestone | Scope | Exit criteria |
|---|---|---|
| **M0 — Scaffold** | Repo/tier layout, coding standards, license + **clean-room policy doc**, CI lint + provenance check. | CI green; provenance check active. |
| **M1 — Core + VTG (sim)** | Tier 0 + v1 patterns + Tier 1 VTG; cocotb + golden frames. | All v1 patterns render correctly (incl. **odd geometry**); timing self/formal-checks pass for 640x480p60 / 1280x720p60 / 1920x1080p60; **stable pattern IDs**, **ppc ABI documented**, and **config atomicity** verified. |
| **M2 — Tang Nano 9K (HW)** | Tier 4 wrapper (rPLL + TMDS PHY), button control; bring-up ladder. | **720p60 must-pass** on a real monitor; 1080p60 attempted; button cycles patterns. |
| **M3 — Portability proof** | AXIS adapter, CSR/I²C control; build on a Lattice ECP5 board (e.g. ULX3S/Colorlight). | Same Tier 0 core, second vendor, patterns on screen; SV-subset accepted by both flows. |
| **M4 — Mode B (+ optional AUTO)** | `timing_measure`, `insertion_mux`; recovered-clock topology. Optional AUTO: `video_mode_mgr` on an **always-on `mgmt_clk`** (FR-AUTO-CLK) with **abrupt** reset-based switch-over — **low-priority**. | Frame substitution locked to an external source on HW. *(Optional: AUTO fallback on source loss demonstrated with abrupt re-sync; supervisor survives recovered-clock loss.)* |
| **M5 — Extensions** | Extended patterns, **real multi-ppc**, more resolutions/boards, exact-SMPTE/PLUGE. | Multi-ppc 1080p/4K demonstrated with the locked ABI; pattern library grown. |

---

## 18. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| 1080p60 serial clock (742.5 MHz) on open Gowin flow | May not close timing on GW1NR-9 | Bring-up ladder; CEA over CVT-RB; **720p60 must-pass** fallback. |
| Recovered-clock AUTO fallback clock-source change | **Low (de-scoped)** — abrupt switch-over accepted per owner | Glitchless transition **dropped**: reset-based abrupt clock-source change (FR-AUTO-4); no glitch-free mux/retrain; feature is optional/low-priority at M4; brief blank/re-sync acceptable. |
| Recovered clock stops on source unplug, stalling the fallback FSM | AUTO fallback fails exactly when it is needed | Run `video_mode_mgr`/timers/reset-control on an always-on `mgmt_clk`; recovered clock is data-plane only (FR-AUTO-CLK). |
| SV-subset acceptance varies per vendor | Build breaks on some flows | Per-milestone supported-target matrix (§12): blocking only for in-matrix targets (Gowin, then Lattice); others are goals; optional `sv2v` Verilog-2001 artifact later. |
| Vendor primitive leakage into portable tree | Breaks portability | Lint/synth gate + provenance check; primitives only in `boards/`. |
| Runtime division/modulo in pixel path | Fmax/area regressions | `ALLOW_RUNTIME_DIV=0` default; pow2/counter/accumulator math (FR-CORE-6); per-pattern CI budget. |
| Genlock instability on marginal sources | Output flapping | Tolerance windows, hysteresis/debounce, defined unlock + relock policy. |
| Half-updated config visible for a frame | Visual glitch on UART/I²C/CSR writes | Atomic frame-boundary commit via `cfg_cdc` (FR-CFG); tested. |
| Open-flow maturity differences (Xilinx/Altera) | Some targets experimental | Document per-target status; vendor-flow fallback. |

---

## 19. Open Questions (owner decisions)

Resolved in v0.2: public RTL language (SV Yosys-tested subset), ppc scope (1 in v1, ABI locked), reuse policy (clean-room + references), Mode B clock topology (recovered-clock end-to-end), license (MIT + LGPL excluded). Resolved in v0.2.1: AUTO-fallback transition is **abrupt** (no glitchless switch / link retrain) and the feature is **low-priority/optional**. Resolved in v0.2.2: AUTO requires an always-on `mgmt_clk` supervisor (FR-AUTO-CLK); register reads expose **both** shadow and active config; **overlay is a separate `INSERT_MODE`** (not a timing mode); CEA/DMT modes use full names with explicit `standard_family`/`vic`.

Still open:

1. **Mode B first capture standard, reference board, & `mgmt_clk` source** — HDMI vs LVDS vs eDP vs FPDLink vs GMSL, and which always-on management clock that board provides for the AUTO supervisor (FR-AUTO-CLK)? (Long-lead hardware decision for M4.)
2. **`RELOCK_POLICY` default** — on source reconnect in AUTO, auto-return to genlock after N stable frames, or stay in fallback until commanded? (Default proposed: stay until commanded; confirm.)
3. **`FALLBACK_RESOLUTION` default** — fixed 720p60 (proposed) vs reuse last measured geometry when the local PLL can generate it?
4. **I²C slave register map** — adopt an existing convention or define our own?
5. **Exact-SMPTE / PLUGE** — which standard and values when the exact color-bar pattern is added (M5)?

---

## 20. Prior Art and References

References studied (clean-room — used for behavior/timing/test strategy only, **not copied** into the portable tree):

| Project | License/status | Used as |
|---|---|---|
| Project F `display_controller` | MIT, Verilog | Primary reference: Mode A display timings, test-card math, DVI/TMDS verification style. |
| Project F **Isle** | MIT, Verilog | Newer Project F display-controller / TMDS-encoder reference; additional timing/TMDS behavior to study before M1. |
| `hdl-util/hdmi` | MIT/Apache-2.0, SystemVerilog | Optional future reference for true HDMI output (packets/audio/infoframes) if needed; Tang Nano 9K noted WIP upstream; TODO list still includes 24-bit color, so not a board-wrapper replacement. |
| LiteVideo | BSD-2, **deprecated**, Migen/LiteX | Mode B/capture and SoC-integration concepts only; not a base for the portable RTL. |
| Sipeed `TangNano-9K-example` | License unclear | HW bring-up notes only; not copied (provenance unclear). |
| AMD/Xilinx Video TPG | proprietary RTL | Feature/control-model **benchmark** (AXIS insertion/pass-through, ramps, solids, bars, checker, zone plate, crosshair, moving box, noise/stuck-pixel, multi-bpc/ppc). |
| OpenCores VGA blocks | LGPL/historical | **Excluded** from the portable tree (copyleft HDL obligations). |

**Clean-room procedure (binding):** No HDL source, comments, test vectors, generated files, or data tables are copied from reference repos into `rtl/reusable/`. Timing tables are sourced from the standards, public timing calculators, or independently authored data — never transcribed from reference HDL. Every external reference used (behavior, timing modes, board primitive recipes) is logged in `PROVENANCE.md`. Any permissively licensed file ever vendored lives **outside** `rtl/reusable/` under `third_party/` with its license header preserved; LGPL/unlicensed HDL is excluded entirely (CI-enforced, §13).

**Standards:** VESA DMT/CVT (incl. Reduced Blanking); CEA-861 (VIC IDs, 60 vs 59.94); DVI 1.0 / HDMI TMDS 8b/10b; AMBA AXI4-Stream / AXI4-Stream Video.

**Toolchain:** Yosys, nextpnr (himbaechel/ecp5/ice40/xilinx), Project Apicula, Project Trellis, Project X-Ray; Gowin GW1NR-9C datasheet (`rPLL`, `OSER10`, `TLVDS_OBUF`); Sipeed Tang Nano 9K schematic/pinout.

---

## 21. License

**MIT** (permissive), chosen for drop-in IP reuse and matching the repo's committed `LICENSE`. By policy, **LGPL or unlicensed HDL is excluded from the portable tree** (`rtl/reusable/`); CI enforces this (§13). *(Note: MIT carries no explicit patent grant — revisit if a patent grant becomes important, e.g. Apache-2.0.)*

---

## 22. Notes to Confirm During Implementation

- The exact GW1NR-9C TMDS PHY recipe (`rPLL` + `CLKDIV` ÷5 → `OSER10` → `TLVDS_OBUF`) is from common Tang Nano HDMI cores and should be **verified against current Gowin primitive docs** when scaffolding `boards/tangnano9k/`.
- CEA VIC assignments and exact pixel clocks should be cross-checked against CEA-861 when the resolution table is authored.

---

## 23. Changelog

**v0.2.2 (2026-06-07)** — Incorporated Codex PRD Review v2:
- Added the **AUTO clock/control-domain contract** (§8.8.1, FR-AUTO-CLK): an always-on `mgmt_clk` runs the fallback supervisor so it survives recovered-clock loss; added clock-valid/reset handshakes and a new risk row (§18). *(Supersedes the v0.2 "glitchless-switch + link-retrain" framing.)*
- Fixed the **stale glitchless verification wording** in §13 (now reset-based fallback tests) and clarified that the sink still re-synchronizes even without FPGA-side link retrain (FR-AUTO-4).
- Clarified the **Tier 0 boundary**: fixed `PATTERN_LATENCY`, emits `rgb`/`de_mask_out` only; sideband alignment via `video_delay` lives in Tier 1/2 (FR-CORE-4, FR-SB-5, §10.1, §15).
- Reworded AUTO as **architecturally-provisioned/optional** wherever it read as a must-have (Goal 4, Goal 9, §5, §13).
- Cleaned up **ppc sideband wording**: `hsync/vsync/sof/eol` are word-level, `x0` is the lane-0 coordinate, `eol` marks the final active **word** (FR-CORE-3, FR-SB-4).
- Reworked the **register map**: split shadow vs active readback (`ACTIVE_*`), scalable `ENABLED_PATTERNS_LO/HI`, split `FALLBACK_CFG`/`FALLBACK_STATUS`, and moved overlay to a separate `INSERT_MODE` field (§10.4, FR-CAP-5).
- Used **full CEA/DMT mode names** with explicit `standard_family`/`vic` fields; dropped bare `480p60` (FR-VTG-3, FR-CLR-5).
- Made the **SV-subset gate a per-milestone supported-target matrix** instead of all-vendors-from-day-one (§10, §12, §15, §18).
- Made **clean-room concrete** (binding procedure + `PROVENANCE.md` + `third_party/`) and added **Project F Isle** to prior art (§14, §20).

**v0.2.1 (2026-06-07)** — De-scoped AUTO fallback per owner direction:
- AUTO fallback transition changed from **glitchless** to **abrupt** (reset-based clock-source change); a brief output blank / display re-sync is now acceptable (§1, §7.2, FR-AUTO-4).
- Dropped the glitch-free clock-mux primitive and live link-retrain requirements; local PLL may be always-on.
- Marked the whole AUTO-fallback feature **low-priority/optional** at M4 (§2.2, §8.8, §17); downgraded the corresponding risk to low/de-scoped (§18).

**v0.2 (2026-06-07)** — Incorporated Codex PRD Review v1:
- Added the **Tier 0–4 reusable model** (§7.1); renamed `rtl/core/` → `rtl/reusable/{pattern,video,stream,cfg}` with Tier 0 as the smallest copyable unit (§14).
- **Locked the multi-ppc lane ABI** (lanes, `de_mask`, packing, `sof`/`eol` lane semantics) while restricting v1 to `PIXELS_PER_CLOCK=1` (§8.1).
- Resolved the **SV-vs-Verilog-2001** contradiction: SystemVerilog **Yosys-tested subset** with CI proving each vendor flow (§10, §12, §15).
- Added the **runtime config atomicity contract** (`cfg_cdc`, latch-on-`sof`, status) (§8.6).
- Specified **coordinate/sideband semantics** and a shared `video_delay` (§8.5).
- Declared **Simple-Sync non-backpressurable** and the **AXIS adapter stall policy** (§8.10).
- Added **synthesis-safe pattern math** constraints (§8.1 FR-CORE-6) and a **pattern ID / parameter ABI** (§8.3).
- Added **color/range/timing precision** (RGB packing, full vs limited range, scaling, approximate-vs-exact bars, CEA/VIC, 60 vs 59.94, CVT-RB caveat) (§9).
- Added the **AUTO genlock→internal fallback** mode manager, with the **recovered-clock topology's glitchless-switch + link-retrain** cost made explicit (§8.7–§8.8, §18).
- Switched the core to **active-high synchronous reset** with CDC isolated in named modules (§15).
- Strengthened **verification** (formal, odd geometry, config atomicity, AXIS stalls, fallback, provenance) (§13).
- Added **prior-art/reference** survey and **clean-room** policy (§20–§21).

**v0.1 (2026-06-07)** — Initial draft.

---

*End of PRD v0.2.2 (Draft).*
