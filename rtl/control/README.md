# rtl/control/ — pluggable control adapters (Tier 3)

These select the active pattern/params and feed the core's config bundle. They
are **not** part of the Tier 0 portability surface (PRD §8.9, FR-CTRL).

| Adapter | Status | Notes |
|---|---|---|
| `gpio_button_ctrl.sv` | **implemented + tested** | Debounced button → `pattern_sel` cycling/wrap (used on Tang Nano 9K; `RESET_SEL` sets the power-on pattern). |
| UART | roadmap | Serial command protocol. |
| I²C slave | roadmap | Register map (PRD §10.4). |
| CSR / Wishbone-lite | roadmap | SoC integration. |

All adapters write shadow registers; the config contract (`cfg_regs` + `cfg_cdc`)
handles CDC and the atomic frame-boundary commit on `sof` (PRD §8.6).
