// SPDX-License-Identifier: MIT
// test-pattern-rtl — Tier 0 — pattern ID ABI
// Stable pattern IDs per PRD §8.3. IDs are STABLE across builds; disabling a
// pattern does NOT renumber others (FR-ABI-1/2). The numeric value doubles as
// the ENABLED_PATTERNS mask bit position (PRD §8.3, §10.4).
`ifndef PATTERN_IDS_SVH
`define PATTERN_IDS_SVH

`define PATTERN_ABI_VERSION 1

`define PAT_BLACK       0
`define PAT_WHITE       1
`define PAT_RED         2
`define PAT_GREEN       3
`define PAT_BLUE        4
`define PAT_GRAY25      5
`define PAT_GRAY50      6
`define PAT_GRAY75      7
`define PAT_COLOR_BARS  8
`define PAT_RAMP_H      9
`define PAT_RAMP_V      10
`define PAT_CHECKER     11
`define PAT_CHECKER_1PX 12
`define PAT_GRID        13
`define PAT_STAIRCASE   14   // horizontal grayscale staircase (discrete steps)

`define PAT_COUNT       15

`endif // PATTERN_IDS_SVH
