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
`define PAT_RAMP_R      15   // red-only horizontal ramp   (TMDS channel isolation)
`define PAT_RAMP_G      16   // green-only horizontal ramp (TMDS channel isolation)
`define PAT_RAMP_B      17   // blue-only horizontal ramp  (TMDS channel isolation)
// Local-dimming benchmark family (Codex PRD review v3) — pat_localdim sub 0..5.
`define PAT_LD_WINDOW       18   // centered white window on black (APL / blooming)
`define PAT_LD_WIN_MOVE     19   // horizontally sweeping window   (dimming tracking)
`define PAT_LD_CHECKER_ZONE 20   // coarse 8x8 zone checker        (ANSI contrast)
`define PAT_LD_NEARBLACK    21   // near-black step wedge          (black crush)
`define PAT_LD_SUBTITLE     22   // subtitle blocks at bottom      (subtitle halo)
`define PAT_LD_FLASH        23   // full-field black<->white flash (response time)
// 1D edge-bar local-dimming family (Codex PRD review v4) — pat_localdim_1d sub 0..7.
`define PAT_LD1D_COLUMN     24   // one centre-zone full-height column   (zone mapping)
`define PAT_LD1D_SWEEP      25   // one-zone column sweeping L->R         (zone tracking)
`define PAT_LD1D_YWIN       26   // top/mid/bottom windows in centre zone (light-guide reach)
`define PAT_LD1D_ALTZONES   27   // even zones white / odd black          (zone separation)
`define PAT_LD1D_HBAND      28   // full-width top/mid/bottom bands        (vertical uniformity)
`define PAT_LD1D_SUBTITLE   29   // white blocks near the bottom edge      (bottom-edge bloom)
`define PAT_LD1D_FLASH      30   // centre-zone column flash               (zone response)
`define PAT_LD1D_DUAL       31   // two columns (1/4 & 3/4 zones)          (independent control)

`define PAT_COUNT       32

`endif // PATTERN_IDS_SVH
