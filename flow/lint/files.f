# Verilator/tooling file list for the portable RTL (run from repo root).
# Used by sim/synth flows. (run_lint.sh discovers files directly.)
+incdir+rtl/reusable/pattern
+incdir+rtl/reusable/video

# Tier 0 — pattern core + patterns
rtl/reusable/pattern/pattern_pixel_core.sv
rtl/reusable/pattern/patterns/pat_color_bars.sv
rtl/reusable/pattern/patterns/pat_ramp.sv
rtl/reusable/pattern/patterns/pat_checker.sv
rtl/reusable/pattern/patterns/pat_grid.sv

# Tier 1/2 — video
rtl/reusable/video/video_timing_gen.sv
rtl/reusable/video/video_source_core.sv
rtl/reusable/video/video_delay.sv
rtl/reusable/video/timing_measure.sv
rtl/reusable/video/timing_source_mux.sv
rtl/reusable/video/video_mode_mgr.sv
rtl/reusable/video/insertion_mux.sv

# Tier 3 — stream / cfg
rtl/reusable/stream/axis_video_wrap.sv
rtl/reusable/cfg/cfg_cdc.sv
rtl/reusable/cfg/cfg_regs.sv
rtl/reusable/cfg/reset_sync.sv

# Control adapters (not part of the Tier 0 portability surface)
rtl/control/gpio_button_ctrl.sv
