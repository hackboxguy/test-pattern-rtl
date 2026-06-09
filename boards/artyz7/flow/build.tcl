# SPDX-License-Identifier: MIT
# Vivado non-project build for the Digilent Arty Z7-20 HDMI test-pattern top.

proc opt_get {name default} {
    global opts
    if {[dict exists $opts $name]} {
        return [dict get $opts $name]
    }
    return $default
}

proc parse_args {} {
    global argv opts
    set opts [dict create]
    foreach arg $argv {
        if {[regexp {^([^=]+)=(.*)$} $arg _ key value]} {
            dict set opts $key $value
        }
    }
}

proc add_report {path text} {
    set fp [open $path "a"]
    puts $fp $text
    close $fp
}

parse_args

set script_dir [file normalize [file dirname [info script]]]
set root       [file normalize [file join $script_dir "../../.."]]
set part       "xc7z020clg400-1"
set top        "top_artyz7"
set res        [opt_get "RES" "1080p"]
set zones      [opt_get "ZONES" "48"]
set strict     [opt_get "STRICT_TIMING" "1"]
set clk_alt    [opt_get "CLK_ALT" "0"]
if {[info exists ::env(ARTYZ7_RES)]} {
    set res $::env(ARTYZ7_RES)
}
if {[info exists ::env(ARTYZ7_ZONES)]} {
    set zones $::env(ARTYZ7_ZONES)
}
if {[info exists ::env(ARTYZ7_STRICT_TIMING)]} {
    set strict $::env(ARTYZ7_STRICT_TIMING)
}
if {[info exists ::env(ARTYZ7_CLK_ALT)]} {
    set clk_alt $::env(ARTYZ7_CLK_ALT)
}

set defines [list "LD1D_ZONES=$zones"]
switch -- $res {
    "480p" {
        set label "640x480p60"
        set pix_mhz "25.1875"
        set ser_mhz "125.9375"
        set ppm "+497"
    }
    "800x600" {
        lappend defines "BUILD_800X600"
        set label "800x600p60"
        set pix_mhz "40.000"
        set ser_mhz "200.000"
        set ppm "0"
    }
    "1024x768" {
        lappend defines "BUILD_1024X768"
        set label "1024x768p60"
        set pix_mhz "65.000"
        set ser_mhz "325.000"
        set ppm "0"
    }
    "720p" {
        lappend defines "BUILD_720P"
        set label "1280x720p60"
        set pix_mhz "74.21875"
        set ser_mhz "371.09375"
        set ppm "-421"
    }
    "1080p" {
        lappend defines "BUILD_1080P"
        set label "1920x1080p60"
        set pix_mhz "148.4375"
        set ser_mhz "742.1875"
        set ppm "-421"
    }
    default {
        puts "ERROR: RES must be 480p, 800x600, 1024x768, 720p, or 1080p (got '$res')"
        exit 2
    }
}
if {$clk_alt eq "1"} {
    lappend defines "TMDS_CLK_ALT"
}

set out_dir [file normalize [file join $root "boards/artyz7/build/$res"]]
file mkdir $out_dir
set latest_report [file normalize [file join $root "boards/artyz7/build/latest_report.txt"]]
if {[file exists $latest_report]} {
    file delete -force $latest_report
}

puts "========================================================================="
puts "Arty Z7-20 Vivado build"
puts "  root       : $root"
puts "  part       : $part"
puts "  mode       : $res ($label)"
puts "  pixel/ser  : $pix_mhz / $ser_mhz MHz"
puts "  clk error  : $ppm ppm vs nominal"
puts "  defines    : $defines"
puts "  output     : $out_dir"
puts "========================================================================="

create_project -in_memory -part $part
set_property target_language Verilog [current_project]
set incdirs [list \
    [file join $root "rtl/reusable/pattern"] \
    [file join $root "rtl/reusable/video"] \
]
set_property include_dirs $incdirs [current_fileset]
set_property verilog_define $defines [current_fileset]

set srcs [list \
    "rtl/reusable/pattern/patterns/pat_color_bars.sv" \
    "rtl/reusable/pattern/patterns/pat_ramp.sv" \
    "rtl/reusable/pattern/patterns/pat_checker.sv" \
    "rtl/reusable/pattern/patterns/pat_grid.sv" \
    "rtl/reusable/pattern/patterns/pat_localdim.sv" \
    "rtl/reusable/pattern/patterns/pat_localdim_1d.sv" \
    "rtl/reusable/pattern/pattern_pixel_core.sv" \
    "rtl/reusable/video/video_timing_gen.sv" \
    "rtl/reusable/video/video_delay.sv" \
    "rtl/reusable/video/video_source_core.sv" \
    "rtl/reusable/cfg/reset_sync.sv" \
    "rtl/control/gpio_button_ctrl.sv" \
    "boards/common/dvi_tmds_encoder.sv" \
    "boards/artyz7/rtl/artyz7_clkgen.sv" \
    "boards/artyz7/rtl/artyz7_tmds_lane.sv" \
    "boards/artyz7/rtl/top_artyz7.sv" \
]

foreach src $srcs {
    read_verilog -sv [file join $root $src]
}
read_xdc [file join $root "boards/artyz7/constraints/artyz7.xdc"]

set_property top $top [current_fileset]

puts "== synth =="
synth_design -top $top -part $part -flatten_hierarchy rebuilt
write_checkpoint -force [file join $out_dir "${top}_synth.dcp"]
report_utilization -file [file join $out_dir "utilization_synth.rpt"]

puts "== implementation =="
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $out_dir "${top}_route.dcp"]

puts "== reports =="
report_utilization -file [file join $out_dir "utilization.rpt"]
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file [file join $out_dir "timing_summary.rpt"]
report_clock_interaction -file [file join $out_dir "clock_interaction.rpt"]
report_clock_networks -file [file join $out_dir "clock_networks.rpt"]
report_drc -file [file join $out_dir "drc.rpt"]
report_methodology -file [file join $out_dir "methodology.rpt"]

set setup_slack "NA"
set hold_slack "NA"
set setup_paths [get_timing_paths -quiet -delay_type max -max_paths 1]
if {[llength $setup_paths] > 0} {
    set setup_slack [format "%.3f" [get_property SLACK [lindex $setup_paths 0]]]
}
set hold_paths [get_timing_paths -quiet -delay_type min -max_paths 1]
if {[llength $hold_paths] > 0} {
    set hold_slack [format "%.3f" [get_property SLACK [lindex $hold_paths 0]]]
}

set timing_ok 1
if {$setup_slack ne "NA" && $setup_slack < 0.0} {
    set timing_ok 0
}
if {$hold_slack ne "NA" && $hold_slack < 0.0} {
    set timing_ok 0
}

set critical_drcs [get_drc_violations -quiet -filter {SEVERITY == "Critical Warning" || SEVERITY == "Error"}]
set drc_count [llength $critical_drcs]

set report_text "================= Arty Z7-20 build report ($res) =================\n"
append report_text "  mode        : $label\n"
append report_text "  clocks      : pixel $pix_mhz MHz, TMDS serial $ser_mhz MHz\n"
append report_text "  clock error : $ppm ppm vs nominal\n"
append report_text "  defines     : $defines\n"
append report_text "  timing      : setup WNS $setup_slack ns, hold WHS $hold_slack ns\n"
append report_text "  DRC         : critical/error violations $drc_count\n"
append report_text "  bitstream   : $out_dir/${top}.bit\n"
append report_text "===================================================================="

puts $report_text
add_report [file join $out_dir "report.txt"] $report_text
add_report $latest_report $report_text

if {$strict eq "1"} {
    if {!$timing_ok} {
        puts "TIMING FAIL: negative setup or hold slack. See timing_summary.rpt."
        exit 1
    }
    if {$drc_count > 0} {
        puts "DRC FAIL: critical/error DRC violations present. See drc.rpt."
        exit 1
    }
}

puts "== bitstream =="
write_bitstream -force [file join $out_dir "${top}.bit"]
puts "Build complete: $out_dir/${top}.bit"
