#!/usr/bin/env bash
# Verilator -Wall lint gate for the portable RTL (PRD §13, §15).
# Lints each module standalone (all M0 modules are leaf modules).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v verilator >/dev/null 2>&1; then
    echo "ERROR: verilator not found on PATH. Install Verilator 5.x." >&2
    exit 127
fi

INCDIRS="+incdir+rtl/reusable/pattern"
mapfile -t FILES < <(find rtl -name '*.sv' | sort)

rc=0
for f in "${FILES[@]}"; do
    echo "== verilator --lint-only -Wall ${f} =="
    if ! verilator --lint-only -Wall -sv ${INCDIRS} "${f}"; then
        rc=1
    fi
done

if [ "${rc}" -eq 0 ]; then
    echo "LINT OK (${#FILES[@]} files)"
else
    echo "LINT FAILED"
fi
exit "${rc}"
