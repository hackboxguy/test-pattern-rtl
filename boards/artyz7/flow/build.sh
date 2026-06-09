#!/usr/bin/env bash
# Vivado flow wrapper for Arty Z7-20 from WSL2.
# Stages sources under C:\Temp so Windows Vivado does not operate from a WSL UNC
# path, then copies reports and bitstreams back into boards/artyz7/build/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

if [ "${1:-}" = "report" ]; then
  if [ -f "boards/artyz7/build/latest_report.txt" ]; then
    cat "boards/artyz7/build/latest_report.txt"
  else
    echo "No Arty Z7 build report yet. Run ./boards/artyz7/flow/build.sh first."
  fi
  exit 0
fi

RES="${RES:-1080p}"
ZONES="${ZONES:-48}"
CLK_ALT="${CLK_ALT:-0}"
STRICT_TIMING="${STRICT_TIMING:-1}"
for arg in "$@"; do
  case "$arg" in
    RES=*) RES="${arg#RES=}" ;;
    ZONES=*) ZONES="${arg#ZONES=}" ;;
    CLK_ALT=*) CLK_ALT="${arg#CLK_ALT=}" ;;
    STRICT_TIMING=*) STRICT_TIMING="${arg#STRICT_TIMING=}" ;;
    *) echo "ERROR: unknown argument '$arg'"; exit 2 ;;
  esac
done

case "$RES" in
  480p) PIX=25.1875; SER=125.9375; PPM=+497 ;;
  800x600) PIX=40.000; SER=200.000; PPM=0 ;;
  1024x768) PIX=65.000; SER=325.000; PPM=0 ;;
  720p) PIX=74.21875; SER=371.09375; PPM=-421 ;;
  1080p) PIX=148.4375; SER=742.1875; PPM=-421 ;;
  *) echo "ERROR: RES must be 480p, 800x600, 1024x768, 720p, or 1080p (got '$RES')"; exit 2 ;;
esac

VIVADO_BAT="${VIVADO_BAT:-/mnt/c/Xilinx/2025.1/Vivado/bin/vivado.bat}"
if [ ! -f "$VIVADO_BAT" ]; then
  echo "ERROR: Vivado batch file not found at $VIVADO_BAT"
  echo "       Set VIVADO_BAT=/mnt/c/path/to/vivado.bat if installed elsewhere."
  exit 1
fi

command -v wslpath >/dev/null 2>&1 || { echo "ERROR: wslpath not found; this wrapper expects WSL."; exit 1; }
WIN_VIVADO="$(wslpath -w "$VIVADO_BAT")"

BUILD_ID="test_pattern_artyz7_${USER:-user}_$$"
WSL_STAGE="/mnt/c/Temp/${BUILD_ID}"
WIN_STAGE="C:\\Temp\\${BUILD_ID}"
mkdir -p "$WSL_STAGE"

cleanup() {
  if [ "${KEEP_STAGE:-0}" != "1" ] && [ -d "$WSL_STAGE" ]; then
    rm -rf "$WSL_STAGE"
  fi
}
trap cleanup EXIT

echo "========================================================================="
echo "Arty Z7-20 Vivado build via WSL"
echo "  RES        : $RES"
echo "  clocks     : pixel $PIX MHz, TMDS serial $SER MHz"
echo "  clk error  : $PPM ppm vs nominal"
echo "  Vivado     : $VIVADO_BAT"
echo "  stage      : $WSL_STAGE"
echo "========================================================================="

mkdir -p "$WSL_STAGE/rtl" "$WSL_STAGE/boards/common" "$WSL_STAGE/boards/artyz7"
cp -R "$ROOT/rtl/reusable" "$WSL_STAGE/rtl/"
cp -R "$ROOT/rtl/control" "$WSL_STAGE/rtl/"
cp -R "$ROOT/boards/common/." "$WSL_STAGE/boards/common/"
cp -R "$ROOT/boards/artyz7/rtl" "$WSL_STAGE/boards/artyz7/"
cp -R "$ROOT/boards/artyz7/constraints" "$WSL_STAGE/boards/artyz7/"
cp -R "$ROOT/boards/artyz7/flow" "$WSL_STAGE/boards/artyz7/"

RUN_TCL="$WSL_STAGE/run_build.tcl"
{
  printf 'set argv [list RES=%s ZONES=%s CLK_ALT=%s STRICT_TIMING=%s]\n' "$RES" "$ZONES" "$CLK_ALT" "$STRICT_TIMING"
  printf 'source boards/artyz7/flow/build.tcl\n'
} > "$RUN_TCL"

set +e
cmd.exe /c "cd /d $WIN_STAGE && call $WIN_VIVADO -mode batch -source run_build.tcl"
status=$?
set -e

LOCAL_OUT="$ROOT/boards/artyz7/build/$RES"
mkdir -p "$LOCAL_OUT"
if [ -d "$WSL_STAGE/boards/artyz7/build/$RES" ]; then
  cp -R "$WSL_STAGE/boards/artyz7/build/$RES/." "$LOCAL_OUT/"
fi
if [ -f "$WSL_STAGE/boards/artyz7/build/latest_report.txt" ]; then
  mkdir -p "$ROOT/boards/artyz7/build"
  cp "$WSL_STAGE/boards/artyz7/build/latest_report.txt" "$ROOT/boards/artyz7/build/latest_report.txt"
fi

if [ "$status" -ne 0 ]; then
  KEEP_STAGE=1
  echo "========================================================================="
  echo "Build failed with exit code $status"
  echo "Copied any available reports to: $LOCAL_OUT"
  echo "Temporary Windows stage preserved at: $WSL_STAGE"
  echo "========================================================================="
  exit "$status"
fi

echo "========================================================================="
echo "Build complete: $LOCAL_OUT/top_artyz7.bit"
echo "Program: openFPGALoader -b arty_z7_20 $LOCAL_OUT/top_artyz7.bit"
echo "========================================================================="
