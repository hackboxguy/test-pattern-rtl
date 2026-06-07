# Provenance & Clean-Room Policy

This project is **clean-room** (PRD §8 Goal 8, §20–§21). The portable tree
(`rtl/reusable/`) is authored from scratch; external projects are used as
behavioral/timing references only.

## Binding rules (CI-enforced by `flow/provenance_check.sh`)

1. **No copied HDL.** No HDL source, comments, test vectors, generated files, or
   data tables are copied from reference repos into `rtl/reusable/`.
2. **Timing tables** are sourced from the standards (VESA DMT/CVT, CEA-861),
   public timing calculators, or independently authored data — never transcribed
   from reference HDL.
3. **No copyleft in the portable tree.** LGPL/unlicensed HDL is excluded from
   `rtl/reusable/`. The CI gate fails on `GPL`/`LGPL`/`copyleft` markers there.
4. **SPDX headers.** Every `rtl/reusable/*.sv|*.svh` carries
   `SPDX-License-Identifier: MIT`.
5. **Vendored code is isolated.** Any permissively licensed file ever vendored
   lives **outside** `rtl/reusable/` under `third_party/`, with its original
   license header preserved.

## External references used (behavior/timing only — not copied)

| Reference | License | Used for |
|---|---|---|
| Project F `display_controller` | MIT | Mode A display timings, test-card style, DVI/TMDS verification approach. |
| Project F Isle | MIT | Newer display-controller / TMDS-encoder behavior to study (M1). |
| `hdl-util/hdmi` | MIT/Apache-2.0 | Optional future true-HDMI output reference (packets/audio/infoframes). |
| LiteVideo | BSD-2 (deprecated) | Mode B/capture & SoC-integration concepts only. |
| Sipeed `TangNano-9K-example` | unclear | HW bring-up notes only (license unconfirmed — not copied). |
| AMD/Xilinx Video TPG | proprietary | Feature/control-model benchmark only. |
| OpenCores VGA blocks | LGPL | Excluded entirely (copyleft). |

> Add a dated row here whenever a new external reference informs the design
> (behavior, a timing mode, or a board primitive recipe).
