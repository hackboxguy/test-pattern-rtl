# flow/

Build, lint, and provenance tooling.

| Path | Purpose |
|---|---|
| `lint/run_lint.sh` | Verilator `-Wall` lint over the portable RTL (per-file). |
| `lint/files.f` | Canonical RTL file list (`+incdir` + sources) for lint/sim/synth. |
| `provenance_check.sh` | Clean-room gate: copyleft markers + SPDX MIT headers. |

Run from the repo root via the top-level `Makefile`:

```bash
make check        # lint + provenance
make lint
make provenance
```

Open-flow synthesis (Yosys + nextpnr-himbaechel/apicula for Gowin, etc.) and the
cocotb/Verilator sim harness are added in M1–M2. The supported-target matrix is
Gowin first, then a Lattice family (PRD §12).
