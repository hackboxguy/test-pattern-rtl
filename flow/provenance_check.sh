#!/usr/bin/env bash
# Clean-room / provenance gate (PRD §13, §20, §21).
#  1) No copyleft (GPL/LGPL) markers anywhere in the portable tree.
#  2) Every reusable RTL file carries the SPDX MIT header.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${ROOT}/rtl/reusable"
status=0

# 1) Copyleft markers must not appear in rtl/reusable/.
if grep -RniE '\b(l?gpl|copyleft|gnu general public)\b' "${TREE}" >/dev/null 2>&1; then
    echo "PROVENANCE FAIL: copyleft marker found in rtl/reusable/:"
    grep -RniE '\b(l?gpl|copyleft|gnu general public)\b' "${TREE}"
    status=1
fi

# 2) SPDX MIT header on every reusable .sv/.svh.
while IFS= read -r f; do
    if ! head -3 "${f}" | grep -q 'SPDX-License-Identifier: MIT'; then
        echo "PROVENANCE FAIL: missing 'SPDX-License-Identifier: MIT' header: ${f}"
        status=1
    fi
done < <(find "${TREE}" \( -name '*.sv' -o -name '*.svh' \))

if [ "${status}" -eq 0 ]; then
    echo "PROVENANCE OK"
fi
exit "${status}"
