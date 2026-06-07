# RTL Coding Standards

Distilled from PRD §15. These are enforced (where automatable) by
`make lint` / `make provenance` and are merge gates.

## Language & portability
- **SystemVerilog, Yosys-tested subset.** Stay within constructs accepted by
  Verilator + Yosys + the open vendor flows. CI proves the subset against the
  **per-milestone supported-target matrix** (Gowin → +Lattice), not every vendor
  from day one (PRD §12).
- **No vendor primitives/attributes** in `rtl/reusable/`. PLLs, serializers, I/O
  buffers, and hard memories live only in `boards/<board>/` (Tier 4).
- One module per file; **module name == file base name** (Verilator
  `DECLFILENAME`).
- SPDX header on every RTL file: `// SPDX-License-Identifier: MIT`.

## Reset & clocks
- Portable RTL uses **active-high synchronous `rst`**. Board wrappers convert
  external reset polarity (`reset_sync`).
- Single core clock domain per instance. No gated/derived clocks, no latches.
- All CDC lives in named modules: `cfg_cdc`, `reset_sync` (add `pulse_cdc` as
  needed). Pattern math contains no CDC.
- AUTO supervision runs on an always-on `mgmt_clk` (PRD §8.8.1, FR-AUTO-CLK).

## Tier 0 boundary
- `pattern_pixel_core` has a fixed `PATTERN_LATENCY` and emits **`rgb` /
  `de_mask_out` only**. Sideband alignment (`hsync/vsync/sof/eol/x0/y/frame/de`)
  is done by the Tier 1/2 wrapper via `video_delay` — never inside Tier 0.
- Multi-pixel-per-clock: the lane ABI is fixed now, but `PIXELS_PER_CLOCK` MUST
  be 1 in v1 (elaboration `$error` otherwise).

## Pattern math (synthesis-safe — PRD §8.1 FR-CORE-6)
- No runtime division/modulo in the pixel datapath.
- Power-of-two block sizes (shifts/masks); grid pitch via counters that reset at
  the pitch; gradients via accumulators. `ALLOW_RUNTIME_DIV` defaults to 0.

## Lint hygiene
- `verilator --lint-only -Wall` must pass.
- Mark intentionally-not-yet-used inputs with a `_unused_*` reduction net, e.g.
  `logic _unused_ok; assign _unused_ok = &{1'b0, sig_a, sig_b};` — the name
  suppresses Verilator's unused-signal warning while documenting intent.
