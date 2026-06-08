# sim/ — verification (implemented)

Self-checking Verilator (`--binary`) testbenches, run via `make sim`
(`flow/sim/run_sim.sh`). All currently pass:

| Testbench | Checks |
|---|---|
| `tb_video_timing_gen` | VTG active/eol/sync counts, first-pixel coord, frame increment (32×24, 13×7, 101×53). |
| `tb_pattern_core` | Every v1 pattern rendered to PPM (`sim/out/`) + checked vs an independent reference; blanking-black; pixel count (normal + odd geometry). |
| `tb_cfg_atomic` | Cross-domain config: active changes only on `sof`, no tearing, `applied_frame` advances. |
| `tb_dvi_tmds_encoder` | DVI TMDS encode→decode round-trip (all 256 bytes + random), control tokens, bounded running disparity. |
| `tb_gpio_button_ctrl` | Debounce + pattern cycle/wrap. |

**Roadmap** (not yet implemented): formal checks (SymbiYosys), Mode B/AUTO
fallback tests, AXIS stall tests, committed golden images.
