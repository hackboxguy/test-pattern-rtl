#!/usr/bin/env bash
# Open-source Gowin flow for the Tang Nano 9K: yosys (synth_gowin) ->
# nextpnr-himbaechel -> gowin_pack -> openFPGALoader.
# Requires OSS CAD Suite (nextpnr-himbaechel + modern yosys). The CLKDIV-based
# clocking needs himbaechel; the older Debian nextpnr-gowin 0.6 cannot place
# CLKDIV. This script auto-activates OSS CAD Suite from $OSS_CAD_SUITE,
# ~/oss-cad-suite, or /opt/oss-cad-suite if it is not already on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
OUT="boards/tangnano9k/build"
mkdir -p "$OUT"

# Ensure the OSS CAD Suite tools (modern yosys, nextpnr-himbaechel, gowin_pack)
# are on PATH. Auto-activate if not already, so a plain ./build.sh just works.
if ! command -v nextpnr-himbaechel >/dev/null 2>&1; then
  for env in "${OSS_CAD_SUITE:+$OSS_CAD_SUITE/environment}" \
             "$HOME/oss-cad-suite/environment" "/opt/oss-cad-suite/environment"; do
    if [ -n "$env" ] && [ -f "$env" ]; then
      # shellcheck source=/dev/null
      source "$env"; break
    fi
  done
fi
for tool in yosys nextpnr-himbaechel gowin_pack; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: '$tool' not found. Install OSS CAD Suite, then either set"
    echo "       OSS_CAD_SUITE=<dir> or 'source <dir>/oss-cad-suite/environment'." >&2
    exit 1; }
done

DEVICE="GW1NR-LV9QN88PC6/I5"   # nextpnr-gowin part string (Tang Nano 9K)
FAMILY="GW1N-9C"               # nextpnr --family / gowin_pack -d
TOP="top_tangnano9k"

# Resolution: RES=480p (default), 720p, or 1080p. PIXFREQ = real pixel clock (MHz).
RES="${RES:-480p}"
case "$RES" in
  480p)    DEFINES="";                PIXFREQ=25.2 ;;
  800x600) DEFINES="-DBUILD_800X600"; PIXFREQ=40 ;;
  720p)    DEFINES="-DBUILD_720P";    PIXFREQ=74.25 ;;
  1080p)   DEFINES="-DBUILD_1080P";   PIXFREQ=148.5 ;;
  *) echo "ERROR: RES must be 480p, 800x600, 720p, or 1080p (got '$RES')"; exit 1 ;;
esac
# Optional 720p PHY experiments (Codex v2): SERIALIZE_CLK=1, CLK_ALT=1.
[ "${SERIALIZE_CLK:-0}" = "1" ] && DEFINES="${DEFINES} -DSERIALIZE_TMDS_CLK"
[ "${CLK_ALT:-0}" = "1" ]       && DEFINES="${DEFINES} -DTMDS_CLK_ALT"
echo "Resolution: ${RES}  (pixel_clk target ${PIXFREQ} MHz)   DEFINES='${DEFINES}'"

SRC=(
  rtl/reusable/pattern/patterns/pat_color_bars.sv
  rtl/reusable/pattern/patterns/pat_ramp.sv
  rtl/reusable/pattern/patterns/pat_checker.sv
  rtl/reusable/pattern/patterns/pat_grid.sv
  rtl/reusable/pattern/pattern_pixel_core.sv
  rtl/reusable/video/video_timing_gen.sv
  rtl/reusable/video/video_delay.sv
  rtl/reusable/video/video_source_core.sv
  rtl/reusable/cfg/reset_sync.sv
  rtl/control/gpio_button_ctrl.sv
  boards/common/dvi_tmds_encoder.sv
  boards/tangnano9k/rtl/gowin_tmds_clkgen.sv
  boards/tangnano9k/rtl/gowin_tmds_lane.sv
  boards/tangnano9k/rtl/top_tangnano9k.sv
)
INCDIRS="-I rtl/reusable/pattern -I rtl/reusable/video"

echo "== synth (yosys synth_gowin) =="
READ=""
for f in "${SRC[@]}"; do READ="${READ} read_verilog -sv ${DEFINES} ${INCDIRS} ${f};"; done
yosys -p "${READ} synth_gowin -top ${TOP} -json ${OUT}/${TOP}.json"

# Placement seed: NEXTPNR_SEED=<n> for a reproducible build (recommended for
# hardware debug); otherwise a random seed (-r). The seed strongly affects the
# 720p clock/output routing quality (Codex v2).
SEED_ARG="-r"
[ -n "${NEXTPNR_SEED:-}" ] && SEED_ARG="--seed ${NEXTPNR_SEED}"

echo "== place & route (nextpnr-himbaechel, timing-driven at ${PIXFREQ} MHz, ${SEED_ARG}) =="
# --freq sets the target for the (otherwise-unconstrained) pixel-clock domain so
# placement/routing is timing-driven at the real pixel clock, not the 12 MHz
# default. --timing-allow-fail keeps the run going so we can report Fmax; the
# post-build checks below turn an under-target Fmax or a marginal serial-clock
# route into a hard failure.
# shellcheck disable=SC2086
nextpnr-himbaechel --timing-allow-fail ${SEED_ARG} --freq "${PIXFREQ}" \
  --json "${OUT}/${TOP}.json" \
  --write "${OUT}/${TOP}_pnr.json" \
  --device "${DEVICE}" \
  --vopt family="${FAMILY}" \
  --vopt cst=boards/tangnano9k/hdmi.cst 2>&1 | tee "${OUT}/pnr.log"

# Serial-clock dedicated-route quality: at 720p, serial_clk (371 MHz) feeds both
# the OSER10 FCLK and CLKDIV. A non-dedicated route here is a strong predictor of
# marginal/garbled 720p output -- fail the build so we don't flash it.
if grep -q "Failed to route net 'serial_clk'" "${OUT}/pnr.log"; then
  echo "TIMING/CLOCK FAIL: serial_clk did not use dedicated routing (marginal clocking)."
  echo "                   Re-run with a different NEXTPNR_SEED."
  [ "${RES}" = "720p" ] && exit 1
fi

# Post-build timing gate: worst reported pixel_clk Fmax must clear the pixel clock.
fmax=$(grep -oE "Max frequency for clock 'pixel_clk': [0-9.]+" "${OUT}/pnr.log" \
       | grep -oE "[0-9.]+$" | sort -n | head -1) || true
if [ -n "${fmax}" ]; then
  echo "pixel_clk Fmax (worst): ${fmax} MHz  (need ${PIXFREQ} MHz)"
  awk "BEGIN{exit !(${fmax} >= ${PIXFREQ})}" || {
    echo "TIMING FAIL: pixel_clk Fmax ${fmax} MHz < ${PIXFREQ} MHz target"; exit 1; }
else
  echo "WARNING: could not parse pixel_clk Fmax from pnr log"
fi

echo "== pack (gowin_pack) =="
gowin_pack -d "${FAMILY}" -o "${OUT}/${TOP}.fs" "${OUT}/${TOP}_pnr.json"

echo "Done -> ${OUT}/${TOP}.fs"
echo "Flash: openFPGALoader -b tangnano9k ${OUT}/${TOP}.fs"
