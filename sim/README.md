# sim/ — verification (harness lands in M1)

Planned (PRD §13):
- **cocotb** (preferred) or SystemVerilog testbenches on Verilator/Icarus.
- **Procedural frame dump:** render each pattern to PPM/PNG; golden-compare in
  CI — including at least one **odd geometry** (e.g. 13×7, 101×53).
- **Formal:** VTG line/frame counters, sync widths, `sof`/`eol`, no mid-frame
  config application.
- **Config atomicity, boundary/clamp, AXIS stall, and (conditional) AUTO
  fallback** tests.

Layout (to be created in M1): `sim/tests/`, `sim/golden/`, `sim/harness/`.
