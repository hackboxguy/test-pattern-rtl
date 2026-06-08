#!/usr/bin/env bash
# Self-checking Verilator simulations (PRD §13). Builds each testbench with
# --binary --timing and runs it; the TB exits non-zero (via $fatal) on any
# mismatch. PPM renders are written to sim/out/ for visual inspection.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
mkdir -p sim/out obj_dir

if ! command -v verilator >/dev/null 2>&1; then
    echo "ERROR: verilator not found on PATH. Install Verilator 5.x." >&2
    exit 127
fi

INC="+incdir+rtl/reusable/pattern +incdir+rtl/reusable/video"
RTL="rtl/reusable/video/video_timing_gen.sv \
     rtl/reusable/video/video_delay.sv \
     rtl/reusable/pattern/patterns/pat_color_bars.sv \
     rtl/reusable/pattern/patterns/pat_ramp.sv \
     rtl/reusable/pattern/patterns/pat_checker.sv \
     rtl/reusable/pattern/patterns/pat_grid.sv \
     rtl/reusable/pattern/patterns/pat_localdim.sv \
     rtl/reusable/pattern/pattern_pixel_core.sv \
     rtl/reusable/video/video_source_core.sv \
     rtl/reusable/cfg/cfg_pipe.sv \
     rtl/reusable/cfg/cfg_regs.sv \
     rtl/reusable/cfg/cfg_cdc.sv \
     rtl/reusable/cfg/cfg_commit.sv \
     boards/common/dvi_tmds_encoder.sv \
     rtl/control/gpio_button_ctrl.sv"

rc=0

# build_run <name> <top> <tb.sv> [extra -G args...]
build_run() {
    local name="$1" top="$2" tb="$3"; shift 3
    local gargs="$*"
    echo "=== build $name ($top $gargs) ==="
    # shellcheck disable=SC2086
    if ! verilator --binary --timing -Wno-fatal -sv $INC $RTL "$tb" \
            --top-module "$top" $gargs \
            --Mdir "obj_dir/$name" -o "$name" >"obj_dir/$name.log" 2>&1; then
        echo "BUILD FAIL $name (see obj_dir/$name.log)"; tail -20 "obj_dir/$name.log"; return 1
    fi
    echo "--- run $name ---"
    if ! "./obj_dir/$name/$name"; then
        echo "RUN FAIL $name"; return 1
    fi
}

# VTG timing — normal + odd geometries
build_run vtg_32x24  tb_video_timing_gen sim/tb_video_timing_gen.sv                 || rc=1
build_run vtg_13x7   tb_video_timing_gen sim/tb_video_timing_gen.sv -GH=13 -GV=7    || rc=1
build_run vtg_101x53 tb_video_timing_gen sim/tb_video_timing_gen.sv -GH=101 -GV=53  || rc=1

# Pattern render/check — normal + odd geometries (13x7, 101x53 per PRD §13)
build_run pat_32x24  tb_pattern_core sim/tb_pattern_core.sv                         || rc=1
build_run pat_13x7   tb_pattern_core sim/tb_pattern_core.sv -GH=13 -GV=7            || rc=1
build_run pat_101x53 tb_pattern_core sim/tb_pattern_core.sv -GH=101 -GV=53          || rc=1

# Config atomicity (cross-domain shadow -> latch-on-sof commit)
build_run cfg_atomic tb_cfg_atomic sim/tb_cfg_atomic.sv                             || rc=1

# DVI TMDS encoder (round-trip + control tokens + DC balance)
build_run tmds tb_dvi_tmds_encoder sim/tb_dvi_tmds_encoder.sv                       || rc=1

# Button control (debounce + pattern cycle/wrap)
build_run gpio tb_gpio_button_ctrl sim/tb_gpio_button_ctrl.sv                       || rc=1

if [ "$rc" -eq 0 ]; then echo "SIM OK"; else echo "SIM FAILED"; fi
exit "$rc"
