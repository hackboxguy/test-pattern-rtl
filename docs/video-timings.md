# Display Video Timings Reference

This document describes all detailed HDMI video timings supported by `pi-config-txt.sh` for the various display types. The raw timing data lives in `display-configs.conf` (in the external Raspberry Pi tooling, **not** in this repo) and is consumed by `pi-config-txt.sh` when generating `/boot/firmware/config.txt`. For the FPGA build, the RTL subset of these timings is transcribed into [`../boards/tangnano9k/displays.conf`](../boards/tangnano9k/displays.conf) (select with `PANEL=<name>`).

The Raspberry Pi `hdmi_timings` field follows this order (17 values):

```
h_active  h_sync_pol  h_front_porch  h_sync_pulse  h_back_porch
v_active  v_sync_pol  v_front_porch  v_sync_pulse  v_back_porch
v_sync_offset_a  v_sync_offset_b  pixel_rep  frame_rate  interlaced  pixel_freq  aspect_ratio
```

Polarity: `0` = negative, `1` = positive. Aspect ratio codes: `1`=4:3, `2`=14:9, `3`=16:9, `4`=5:4, `5`=16:10, `6`=15:9, `7`=21:9, `8`=64:27.

## Horizontal Timing

| Display Type | Resolution | H Active (px) | H Front Porch | H Sync Pulse | H Back Porch | H Total | H Sync Polarity |
|--------------|-----------|---------------|---------------|--------------|--------------|---------|-----------------|
| `12.3`       | 1920×720  | 1920          | 50            | 50           | 50           | 2070    | Negative        |
| `12.3-nq1`   | 1920×720  | 1920          | 50            | 50           | 54           | 2074    | Negative        |
| `14.6-fhd`   | 1920×1080 | 1920          | 76            | 22           | 10           | 2028    | Negative        |
| `14.6-2k5`   | 2560×1440 | 2560          | 10            | 18           | 216          | 2804    | Negative        |
| `15.6-2k5`   | 2560×1440 | 2560          | 10            | 24           | 222          | 2816    | Negative        |
| `17.3-3k`    | 2880×1620 | 2880          | 48            | 48           | 108          | 3084    | Negative        |
| `27`         | 4032×756  | 4032          | 72            | 72           | 72           | 4248    | Negative        |

## Vertical Timing

| Display Type | Resolution | V Active (lines) | V Front Porch | V Sync Pulse | V Back Porch | V Total | V Sync Polarity |
|--------------|-----------|------------------|---------------|--------------|--------------|---------|-----------------|
| `12.3`       | 1920×720  | 720              | 21            | 2            | 18           | 761     | Negative        |
| `12.3-nq1`   | 1920×720  | 720              | 21            | 2            | 18           | 761     | Negative        |
| `14.6-fhd`   | 1920×1080 | 1080             | 28            | 4            | 10           | 1122    | Negative        |
| `14.6-2k5`   | 2560×1440 | 1440             | 10            | 4            | 330          | 1784    | Negative        |
| `15.6-2k5`   | 2560×1440 | 1440             | 11            | 3            | 38           | 1492    | Negative        |
| `17.3-3k`    | 2880×1620 | 1620             | 10            | 6            | 36           | 1672    | Negative        |
| `27`         | 4032×756  | 756              | 12            | 2            | 16           | 786     | Negative        |

## Clock & Frame Rate

| Display Type | Pixel Clock (Hz) | Pixel Clock (MHz) | Declared Frame Rate (Hz) | Computed Frame Rate (Hz) | Aspect Ratio Code |
|--------------|------------------|-------------------|--------------------------|--------------------------|-------------------|
| `12.3`       | 94,520,000       | 94.52             | 60                       | 60.00                    | 4 (5:4)           |
| `12.3-nq1`   | 94,520,000       | 94.52             | 60                       | 59.88                    | 4 (5:4)           |
| `14.6-fhd`   | 136,687,000      | 136.69            | 60                       | 60.07                    | 3 (16:9)          |
| `14.6-2k5`   | 300,000,000      | 300.00            | 60                       | 59.97                    | 4 (5:4)           |
| `15.6-2k5`   | 261,888,000      | 261.89            | 62                       | 62.32                    | 4 (5:4)           |
| `17.3-3k`    | 314,280,000      | 314.28            | 60                       | 60.95                    | 3 (16:9)          |
| `27`         | 207,000,000      | 207.00            | 62                       | 62.00                    | 4 (5:4)           |

> Computed frame rate = `pixel_clock / (H_total × V_total)`. Minor deviations from declared rate are normal and accepted by most HDMI displays.

## Framebuffer Dimensions

| Display Type | Resolution | Framebuffer W | Framebuffer H | Description                                |
|--------------|-----------|---------------|---------------|--------------------------------------------|
| `12.3`       | 1920×720  | 1920          | 720           | 12.3" display                              |
| `12.3-nq1`   | 1920×720  | 1920          | 720           | 12.3" NQ1 display                          |
| `14.6-fhd`   | 1920×1080 | 1920          | 1080          | 14.6" FHD display                          |
| `14.6-2k5`   | 2560×1440 | 2560          | 1440          | 14.6" 2.5K display                         |
| `15.6-2k5`   | 2560×1440 | 2560          | 1440          | 15.6" 2.5K display                         |
| `17.3-3k`    | 2880×1620 | 2880          | 1620          | 17.3" 3K display                           |
| `27`         | 4032×756  | 4032          | 756           | 27" display                                |

## Auto-Detection Modes

These types do not use fixed timings — the Pi reads timings from the display's EDID via DDC.

| Display Type  | Behavior                                                             |
|---------------|----------------------------------------------------------------------|
| `edid`        | Full KMS (`dtoverlay=vc4-kms-v3d`) + `display_auto_detect=1`. Loads hh983-serializer and himax-touch as usual. |
| `edid-hdmi`   | Same KMS config as `edid` but also disables hh983-serializer and himax-touch driver loading. Intended for direct HDMI displays. |

## Common Settings (All Fixed-Timing Types)

When a fixed-timing display is selected, `pi-config-txt.sh` writes the following lines to `config.txt`:

```
dtoverlay=vc4-fkms-v3d
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_timings=<timing values from this table>
hdmi_pixel_freq_limit=<pixel clock from this table>
framebuffer_width=<W from this table>
framebuffer_height=<H from this table>
max_framebuffer_width=<W>
max_framebuffer_height=<H>
config_hdmi_boost=4
```

## HH983 Serializer Mode

The display type also determines the FPDLink deserializer pairing via `/etc/modprobe.d/hh983.conf`:

| Display Type   | hh983 `config_mode` | Pairing      |
|----------------|---------------------|--------------|
| `12.3-nq1`     | 0                   | 983 + 984    |
| `15.6-2k5`     | 0                   | 983 + 984    |
| `edid-hdmi`    | (driver disabled)   | none         |
| All others     | 1                   | 983 + 988    |

## als-dimmer Configuration

Two display types switch the `/home/pi/als-dimmer/etc/als-dimmer/config.json` symlink:

| Display Type   | als-dimmer config target                                |
|----------------|---------------------------------------------------------|
| `12.3-nq1`     | `config_fpga_opti4001_dimmer2048_12_3_nq1v1.json`       |
| `15.6-2k5`     | `config_fpga_opti4001_dimmer2048_15_6_0od.json`         |
| All others     | Symlink left untouched                                  |
