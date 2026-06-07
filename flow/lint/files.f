# Verilator/tooling file list for the portable RTL (run from repo root).
# Used by lint and (later) sim/synth flows.
+incdir+rtl/reusable/pattern

# Tier 0 — pattern core
rtl/reusable/pattern/pattern_pixel_core.sv

# Tier 1/2 — video
rtl/reusable/video/video_timing_gen.sv
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
