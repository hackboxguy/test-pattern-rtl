# test-pattern-rtl

A hardware-agnostic, synthesizable RTL core that procedurally generates display
**test patterns** (color bars, gradients, checkerboards, grids, solid fields) for
validating displays of arbitrary resolution on any FPGA.

The reusable core has **no vendor primitives** — device-specific logic (PLLs,
TMDS/DVI serializers, capture PHYs) lives in thin board wrappers. First target is
the **Sipeed Tang Nano 9K** (HDMI out via DVI/TMDS); later boards add external
capture (HDMI/FPDLink/GMSL/eDP/LVDS) for genlock/insertion.

> **Status: Mode A implemented & hardware-confirmed.** Tier 0/1 core (VTG +
> 14-pattern v1 set + config atomicity) is built and simulation-tested; the
> Tang Nano 9K HDMI path runs **640x480p60 and 1280x720p60 on real hardware**
> (DVI/TMDS via Gowin OSER10/ELVDS). 1080p60 is not achievable on this board
> (rPLL caps at 600 MHz). Mode B / AUTO / AXIS modules are interface stubs
> (later milestones). See the PRD milestones.

📄 **Full spec:** [docs/pattern-generator-rtl-prd.md](docs/pattern-generator-rtl-prd.md)

## Reusable tiers (copy only what you need)

| Tier | Path | Responsibility |
|---|---|---|
| 0 | `rtl/reusable/pattern/` | Pure `(x0, y, frame, config) → rgb` engine. **Smallest copyable unit.** |
| 1 | `rtl/reusable/video/` | VTG, sideband alignment (`video_delay`) → free-running Simple-Sync. |
| 2 | `rtl/reusable/video/` | Captured-timing measure, insertion, AUTO mode manager. |
| 3 | `rtl/reusable/{stream,cfg}/`, `rtl/control/` | AXI4-Stream wrap, CSR/CDC, GPIO/UART/I²C adapters. |
| 4 | `boards/<board>/` | PLLs, serializers, I/O, PHYs, constraints. **Not portable.** |

## Layout

```
rtl/reusable/   portable RTL (tiers 0–3)
rtl/control/    pluggable control adapters
boards/         per-board wrappers (tier 4) — tangnano9k first
sim/            cocotb / Verilator tests, golden frames (M1)
flow/           lint + provenance scripts, build flows
docs/           PRD + reviews + coding standards
third_party/    any vendored permissive code (OUTSIDE rtl/reusable/)
```

## Quickstart

Requires **Verilator 5.x** (`apt-get install verilator`).

```bash
make check        # lint + provenance (the M0 CI gates)
make lint         # Verilator -Wall over the portable RTL
make provenance   # clean-room / SPDX header check
```

## License

MIT — see [LICENSE](LICENSE). By policy, LGPL/unlicensed HDL is excluded from
`rtl/reusable/` (enforced by `make provenance`). See
[PROVENANCE.md](PROVENANCE.md).
