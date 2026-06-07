# rtl/control/ — pluggable control adapters (Tier 3)

These select the active pattern/params and feed the core's config bundle. They
are **not** part of the Tier 0 portability surface (PRD §8.9, FR-CTRL).

| Adapter | Status | Notes |
|---|---|---|
| `gpio_button_ctrl.sv` | stub (M2) | Debounced button → `pattern_sel` cycling (Tang Nano). |
| UART | M3 | Serial command protocol. |
| I²C slave | M3 | Register map (PRD §10.4). |
| CSR / Wishbone-lite | M3 | SoC integration. |

All adapters write shadow registers; the config contract (`cfg_regs` + `cfg_cdc`)
handles CDC and the atomic frame-boundary commit on `sof` (PRD §8.6).
