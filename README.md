# test-pattern-rtl

A hardware-agnostic, synthesizable RTL core that procedurally generates display
**test patterns** (color bars, gradients, checkerboards, grids, solid fields) for
validating displays of arbitrary resolution on any FPGA.

The reusable core has **no vendor primitives** — device-specific logic (PLLs,
TMDS/DVI serializers, capture PHYs) lives in thin board wrappers. First target is
the **Sipeed Tang Nano 9K** (HDMI out via DVI/TMDS); later boards add external
capture (HDMI/FPDLink/GMSL/eDP/LVDS) for genlock/insertion.

> **Status: Mode A implemented & hardware-confirmed.** Tier 0/1 core (VTG +
> 32-pattern set (incl. 2D + 1D local-dimming) + config atomicity) is built and simulation-tested; the Tang
> Nano 9K HDMI path (DVI/TMDS via Gowin OSER10/ELVDS) runs **clean on real
> hardware at 480p, 800×600, and 1024×768 (XGA)**. 720p is marginal on the board's
> emulated-LVDS (PHY rate limit, not the RTL); 1080p is not achievable (rPLL caps
> at 600 MHz). Mode B / AUTO / AXIS modules are interface stubs (later milestones).
> See [`CLAUDE.md`](CLAUDE.md) for current status, the PRD for the design spec.

📄 **Full spec:** [docs/pattern-generator-rtl-prd.md](docs/pattern-generator-rtl-prd.md)

## Getting started: fresh Ubuntu 24.04 → live HDMI patterns

From a blank Ubuntu 24.04 box to test patterns on a screen in ~10 minutes.

**You need:** a Sipeed **Tang Nano 9K**, a USB-C cable (board ↔ PC), an HDMI
cable, and a monitor.

### 1 · Install the tools

```bash
# git + simulator + USB flasher (all in Ubuntu 24.04 'universe')
sudo apt update
sudo apt install -y git curl verilator openfpgaloader

# FPGA build tools — Yosys + nextpnr-himbaechel + gowin_pack, via OSS CAD Suite.
# (Not in apt; download the prebuilt tarball into your home dir.)
cd ~
URL=$(curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest \
      | grep -o 'https://[^"]*oss-cad-suite-linux-x64-[^"]*\.tgz' | head -1)
wget -O oss-cad-suite.tgz "$URL" && tar xzf oss-cad-suite.tgz      # creates ~/oss-cad-suite
```

`build.sh` auto-activates OSS CAD Suite from `~/oss-cad-suite` — no manual
`source` needed.

### 2 · Allow USB flashing (one-time)

The `openfpgaloader` package installs the needed udev rules. Add yourself to the
`plugdev` group, then log out/in (or just unplug/replug the board):

```bash
sudo usermod -aG plugdev "$USER"
```

(If a flash later reports a USB permission error, just prefix it with `sudo`.)

### 3 · Clone, build, flash

```bash
git clone https://github.com/hackboxguy/test-pattern-rtl.git
cd test-pattern-rtl

RES=1024x768 ./boards/tangnano9k/flow/build.sh     # ~1 min; prints a timing/resource report
openFPGALoader -b tangnano9k boards/tangnano9k/build/top_tangnano9k.fs
```

### 4 · What you should see

**Color bars** appear within a couple of seconds. Then use the two buttons:

- **S2** — cycle through all **32 patterns** (solids, grays, H/V ramps, checker,
  grid, R/G/B channel-isolation ramps, a **2D local-dimming suite** (window,
  moving window, zone checker, near-black wedge, subtitle, flash), and a **1D
  edge-bar local-dimming suite** (zone column, sweep, y-window, alternating
  zones, h-band, subtitle, flash, dual-highlight) for backlight benchmarking).
- **S1** — reset back to color bars.

`RES=1024x768` (XGA) is the highest rock-solid mode; on a 16:9 panel it shows
pillarboxed. If your monitor is fussy, the most universally-compatible build is
`RES=480p` (see the resolution table below).

### 5 · (optional) Run the simulations / CI gates

```bash
make check      # Verilator lint + Yosys smoke + provenance + self-checking sims
```

> **Troubleshooting** · `openFPGALoader: command not found` → `sudo apt install openfpgaloader`.
> Build can't find Yosys/nextpnr → confirm OSS CAD Suite extracted to `~/oss-cad-suite`.
> Monitor says "no signal" → try `RES=480p` (most compatible) or a different cable/port.

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

## Quickstart (simulation / CI gates)

Requires **Verilator 5.x** (`apt-get install verilator`).

```bash
make check        # all gates: lint + Yosys-subset smoke + provenance + self-checking sims
make lint         # Verilator -Wall over the portable RTL
make sim          # self-checking pattern/VTG sims (incl. odd geometries)
make provenance   # clean-room / SPDX header check
```

## Resolutions & build reference

(First build? See the **Getting started** section above for tool install.)
Resolution is selected by `RES=` on the build:

```bash
RES=1024x768 ./boards/tangnano9k/flow/build.sh
```

The clean/marginal boundary is the board's emulated-LVDS **serial bit rate**, not
the RTL (details in [boards/tangnano9k/README.md](boards/tangnano9k/README.md)):

| `RES=` | Mode | pixel / serial clock | Result on Tang Nano 9K |
|---|---|---|---|
| `480p` *(default)* | 640×480p60 (4:3) | 25.2 / 126 MHz | ✅ clean |
| `800x600` | 800×600p60 (4:3) | 40 / 200 MHz | ✅ clean |
| `1024x768` | 1024×768p60 / XGA (4:3) | 65 / 325 MHz | ✅ **clean — highest confirmed** |
| `720rb` | 1280×720p60 reduced-blank (16:9) | 64.8 / 324 MHz | ⚠️ marginal (short blanking; needs a tolerant sink) |
| `720p` | 1280×720p60 (16:9) | 74.25 / 371 MHz | ❌ above the ELVDS cliff (artifacts) |
| `1920x720` | 1920×720p60 (1D-dimming panel, 40-LED) | ~92 / ~459 MHz | ❌ builds & closes fabric timing, but **~40 % over the ELVDS cliff** — wired for a future faster-serializer board (`ZONES=40`) |
| `1080p` | 1920×1080p60 (16:9) | 148.5 / 742.5 MHz | ❌ not buildable (rPLL caps at 600 MHz) |

**P&R seed is pinned** (`NEXTPNR_SEED=2`) so placement — and clock quality near the
cliff — is reproducible; the build fails any high-rate mode whose TMDS clock can't
route cleanly. Override with `NEXTPNR_SEED=<n>` to sweep, or `NEXTPNR_SEED=r` for random.

For the **1D edge-bar local-dimming** patterns, set the zone count to your panel's
LED count with `ZONES=<n>` (default 48), e.g. `ZONES=40 RES=1024x768 ./…/build.sh`.
The patterns are resolution-independent; the two target panels — `1920×720` (40
LEDs) and `2560×1440` (47 LEDs) — have mode profiles in `video_modes.svh` but
exceed this board's PHY, so they need a faster-serializer board (preview them at
a clean res on the Tang Nano).

### Timing & resource report

Every build prints a timing + resource summary (and saves it to
`boards/tangnano9k/build/report.txt`). Re-view the last build's report without
rebuilding:

```bash
make report                                   # or:
./boards/tangnano9k/flow/build.sh report
```

```
================= Tang Nano 9K build report (RES=1024x768) =================
  pixel clock : 65 MHz      TMDS serial (bit) clock : 325.0 MHz
  timing      : pixel_clk Fmax 86.93 MHz  (target 65 MHz, +34% margin)
  clock route : serial_clk OK
  resources   :
      ALU            474 / 6480     7%
      DFF            267 / 6480     4%
      LUT4          1109 / 8640    12%
      MULT18X18        2 / 20      10%
      rPLL             1 / 2       50%
      ...
```

## License

MIT — see [LICENSE](LICENSE). By policy, LGPL/unlicensed HDL is excluded from
`rtl/reusable/` (enforced by `make provenance`). See
[PROVENANCE.md](PROVENANCE.md).
