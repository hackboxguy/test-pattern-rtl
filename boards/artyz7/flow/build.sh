#!/usr/bin/env bash
# Vivado flow wrapper for Arty Z7-20.
# Runs native Linux Vivado when available, otherwise falls back to Windows Vivado
# from WSL2. In both cases sources are staged so tool scratch files stay out of
# the repo, then reports and bitstreams are copied back into boards/artyz7/build/.
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
  1440p) PIX=240.000; SER=1200.000; PPM=-7030 ;;
  *) echo "ERROR: RES must be 480p, 800x600, 1024x768, 720p, 1080p, or 1440p (got '$RES')"; exit 2 ;;
esac

prepare_stage() {
  mkdir -p "$STAGE_DIR/rtl" "$STAGE_DIR/boards/common" "$STAGE_DIR/boards/artyz7"
  cp -R "$ROOT/rtl/reusable" "$STAGE_DIR/rtl/"
  cp -R "$ROOT/rtl/control" "$STAGE_DIR/rtl/"
  cp -R "$ROOT/boards/common/." "$STAGE_DIR/boards/common/"
  cp -R "$ROOT/boards/artyz7/rtl" "$STAGE_DIR/boards/artyz7/"
  cp -R "$ROOT/boards/artyz7/constraints" "$STAGE_DIR/boards/artyz7/"
  cp -R "$ROOT/boards/artyz7/flow" "$STAGE_DIR/boards/artyz7/"

  RUN_TCL="$STAGE_DIR/run_build.tcl"
  {
    printf 'set argv [list RES=%s ZONES=%s CLK_ALT=%s STRICT_TIMING=%s]\n' "$RES" "$ZONES" "$CLK_ALT" "$STRICT_TIMING"
    printf 'source boards/artyz7/flow/build.tcl\n'
  } > "$RUN_TCL"
}

write_windows_launcher() {
  RUN_BAT="$STAGE_DIR/run_vivado.bat"
  {
    printf '@echo off\r\n'
    printf 'cd /d "%%~dp0"\r\n'
    printf 'call "%s" -mode batch -source run_build.tcl\r\n' "$WIN_VIVADO"
    printf 'exit /b %%ERRORLEVEL%%\r\n'
  } > "$RUN_BAT"
}

copy_results() {
  LOCAL_OUT="$ROOT/boards/artyz7/build/$RES"
  mkdir -p "$LOCAL_OUT"
  if [ -d "$STAGE_DIR/boards/artyz7/build/$RES" ]; then
    cp -R "$STAGE_DIR/boards/artyz7/build/$RES/." "$LOCAL_OUT/"
  fi
  if [ -f "$STAGE_DIR/boards/artyz7/build/latest_report.txt" ]; then
    mkdir -p "$ROOT/boards/artyz7/build"
    cp "$STAGE_DIR/boards/artyz7/build/latest_report.txt" "$ROOT/boards/artyz7/build/latest_report.txt"
  fi
}

finish_or_fail() {
  local status="$1"
  copy_results
  if [ "$status" -ne 0 ]; then
    KEEP_STAGE=1
    echo "========================================================================="
    echo "Build failed with exit code $status"
    echo "Copied any available reports to: $LOCAL_OUT"
    echo "Temporary stage preserved at: $STAGE_DIR"
    echo "========================================================================="
    exit "$status"
  fi

  echo "========================================================================="
  echo "Build complete: $LOCAL_OUT/top_artyz7.bit"
  echo "Program: openFPGALoader -b arty_z7_20 $LOCAL_OUT/top_artyz7.bit"
  echo "========================================================================="
}

cleanup() {
  if [ "${KEEP_STAGE:-0}" != "1" ] && [ -n "${STAGE_DIR:-}" ] && [ -d "$STAGE_DIR" ]; then
    rm -rf "$STAGE_DIR"
  fi
}
trap cleanup EXIT

FLOW_MODE="${ARTYZ7_VIVADO_MODE:-auto}"
case "$FLOW_MODE" in
  auto|native|windows) ;;
  *) echo "ERROR: ARTYZ7_VIVADO_MODE must be auto, native, or windows"; exit 2 ;;
esac

NATIVE_VIVADO=()
if [ "$FLOW_MODE" != "windows" ]; then
  if [ -n "${VIVADO:-}" ]; then
    if [ -x "$VIVADO" ] || command -v "$VIVADO" >/dev/null 2>&1; then
      NATIVE_VIVADO=("$VIVADO")
    else
      echo "ERROR: VIVADO is set but not executable/found: $VIVADO"
      exit 1
    fi
  elif command -v vivado >/dev/null 2>&1; then
    NATIVE_VIVADO=("vivado")
  elif [ "$FLOW_MODE" = "native" ]; then
    echo "ERROR: native Vivado not found on PATH. Set VIVADO=/path/to/vivado."
    exit 1
  fi
fi

if [ "${#NATIVE_VIVADO[@]}" -gt 0 ]; then
  STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/test_pattern_artyz7_${USER:-user}_XXXXXX")"
  prepare_stage

  echo "========================================================================="
  echo "Arty Z7-20 Vivado build via native Linux"
  echo "  RES        : $RES"
  echo "  clocks     : pixel $PIX MHz, TMDS serial $SER MHz"
  echo "  clk error  : $PPM ppm vs nominal"
  echo "  Vivado     : ${NATIVE_VIVADO[*]}"
  echo "  stage      : $STAGE_DIR"
  echo "========================================================================="

  set +e
  (cd "$STAGE_DIR" && "${NATIVE_VIVADO[@]}" -mode batch -source run_build.tcl)
  status=$?
  set -e
  finish_or_fail "$status"
  exit 0
fi

VIVADO_BAT="${VIVADO_BAT:-/mnt/c/Xilinx/2025.1/Vivado/bin/vivado.bat}"
if [ "$FLOW_MODE" = "native" ]; then
  echo "ERROR: native Vivado not found on PATH. Set VIVADO=/path/to/vivado."
  exit 1
fi

if [ ! -f "$VIVADO_BAT" ]; then
  echo "ERROR: no native vivado found and Vivado batch file not found at $VIVADO_BAT"
  echo "       Set VIVADO=/path/to/vivado for native Linux, or VIVADO_BAT=/mnt/c/path/to/vivado.bat for WSL."
  exit 1
fi
command -v wslpath >/dev/null 2>&1 || { echo "ERROR: wslpath not found; Windows Vivado fallback expects WSL."; exit 1; }
command -v cmd.exe >/dev/null 2>&1 || { echo "ERROR: cmd.exe not found; Windows Vivado fallback expects WSL."; exit 1; }

STAGE_ROOT="${ARTYZ7_WSL_STAGE_ROOT:-/mnt/c/Temp}"
STAGE_DIR="$(mktemp -d "$STAGE_ROOT/test_pattern_artyz7_${USER:-user}_XXXXXX")"
prepare_stage
WIN_VIVADO="$(wslpath -w "$VIVADO_BAT")"
write_windows_launcher
WIN_RUN_BAT="$(wslpath -w "$RUN_BAT")"

echo "========================================================================="
echo "Arty Z7-20 Vivado build via WSL/Windows"
echo "  RES        : $RES"
echo "  clocks     : pixel $PIX MHz, TMDS serial $SER MHz"
echo "  clk error  : $PPM ppm vs nominal"
echo "  Vivado     : $VIVADO_BAT"
echo "  stage      : $STAGE_DIR"
echo "========================================================================="

set +e
cmd.exe /c "$WIN_RUN_BAT"
status=$?
set -e
finish_or_fail "$status"
