#!/usr/bin/env bash
# Yosys read_verilog smoke (PRD §13). Proves the portable RTL + vendor-neutral
# board logic parses under Yosys's front-end -- the one the open Gowin/Lattice
# flows use -- so we stay within a genuinely Yosys-tested SystemVerilog subset
# (not just Verilator-clean). Each file is parsed standalone (submodules resolve
# as black boxes; this checks syntax, not elaboration).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v yosys >/dev/null 2>&1; then
    echo "ERROR: yosys not found on PATH." >&2
    exit 127
fi

INC="-I rtl/reusable/pattern -I rtl/reusable/video"
rc=0
while IFS= read -r f; do
    if yosys -p "read_verilog -sv ${INC} ${f}" >/dev/null 2>/tmp/yosys_smoke.err; then
        echo "ok   ${f}"
    else
        echo "FAIL ${f}"
        grep -i error /tmp/yosys_smoke.err | head -2
        rc=1
    fi
done < <(find rtl boards/common -name '*.sv' | sort)

if [ "${rc}" -eq 0 ]; then echo "YOSYS SMOKE OK"; else echo "YOSYS SMOKE FAILED"; fi
exit "${rc}"
