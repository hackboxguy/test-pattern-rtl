#!/usr/bin/env bash
# Open-source Gowin flow for the Tang Nano 9K: yosys (synth_gowin) ->
# nextpnr-himbaechel (Project Apicula) -> gowin_pack.
#
# !! UNVERIFIED end-to-end in this repo: nextpnr-himbaechel / gowin_pack are not
#    available in CI and there is no board here. The exact device string and
#    nextpnr invocation are toolchain-version specific -- verify against your
#    OSS CAD Suite / apicula version. Flash the resulting .fs with openFPGALoader.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"
OUT="boards/tangnano9k/build"
mkdir -p "$OUT"

DEVICE="GW1NR-LV9QN88PC6/I5"   # Tang Nano 9K part — verify exact speed grade
FAMILY="GW1N-9C"
TOP="top_tangnano9k"

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
for f in "${SRC[@]}"; do READ="${READ} read_verilog -sv ${INCDIRS} ${f};"; done
yosys -p "${READ} synth_gowin -top ${TOP} -json ${OUT}/${TOP}.json"

echo "== place & route (nextpnr-himbaechel) =="
nextpnr-himbaechel \
  --json "${OUT}/${TOP}.json" \
  --write "${OUT}/${TOP}_pnr.json" \
  --device "${DEVICE}" \
  --vopt cst=boards/tangnano9k/hdmi.cst

echo "== pack (gowin_pack) =="
gowin_pack -d "${FAMILY}" -o "${OUT}/${TOP}.fs" "${OUT}/${TOP}_pnr.json"

echo "Done -> ${OUT}/${TOP}.fs"
echo "Flash: openFPGALoader -b tangnano9k ${OUT}/${TOP}.fs"
