#!/usr/bin/env bash
# Verilator -Wall lint gate for the portable RTL (PRD §13, §15).
# Each module is linted as the top of its own hierarchy, with all sources
# provided so submodules resolve.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v verilator >/dev/null 2>&1; then
    echo "ERROR: verilator not found on PATH. Install Verilator 5.x." >&2
    exit 127
fi

INC="+incdir+rtl/reusable/pattern +incdir+rtl/reusable/video"
# Portable RTL + vendor-neutral board-common logic (DVI TMDS encoder, etc.).
# Vendor-specific board code (boards/<vendor>/) needs the vendor flow, not Verilator.
mapfile -t FILES < <(find rtl boards/common -name '*.sv' | sort)

rc=0
for f in "${FILES[@]}"; do
    mod="$(basename "$f" .sv)"
    echo "== verilator --lint-only -Wall --top-module ${mod} =="
    # shellcheck disable=SC2086
    if ! verilator --lint-only -Wall -sv ${INC} --top-module "${mod}" "${FILES[@]}"; then
        rc=1
    fi
done

if [ "${rc}" -eq 0 ]; then
    echo "LINT OK (${#FILES[@]} modules)"
else
    echo "LINT FAILED"
fi
exit "${rc}"
