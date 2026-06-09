# boards/artyz7/ - Tier 4 wrapper (Digilent Arty Z7-20, XC7Z020)

PL-only HDMI/DVI test-pattern output for the Arty Z7-20. The design uses the
board's 125 MHz PL oscillator, a 7-series MMCM, the existing reusable pattern
core, the project-owned DVI/TMDS encoder, OSERDESE2 10:1 serializers, and OBUFDS
TMDS outputs on the HDMI source connector J11.

## Build

This board uses Vivado. The wrapper runs native Linux Vivado when `vivado` is on
`PATH` or `VIVADO=/path/to/vivado` is set. On WSL2 without native Vivado it falls
back to Windows Vivado 2025.1 from
`/mnt/c/Xilinx/2025.1/Vivado/bin/vivado.bat`, stages the build under `C:\Temp`,
then copies reports and bitstreams back to `boards/artyz7/build/`.

```bash
./boards/artyz7/flow/build.sh                  # 1920x1080p60 default
./boards/artyz7/flow/build.sh RES=480p         # safe bring-up fallback
./boards/artyz7/flow/build.sh RES=720p         # Tang comparison mode
./boards/artyz7/flow/build.sh RES=1440p        # 2560x1440 reduced-blanking stress mode
./boards/artyz7/flow/build.sh report           # last build summary
make build-artyz7 RES=1440p ZONES=47           # make wrapper
```

Useful tool-selection overrides:

```bash
VIVADO=/opt/Xilinx/Vivado/2025.1/bin/vivado ./boards/artyz7/flow/build.sh RES=1080p
ARTYZ7_VIVADO_MODE=windows ./boards/artyz7/flow/build.sh RES=1080p
VIVADO_BAT=/mnt/c/Xilinx/2025.1/Vivado/bin/vivado.bat ./boards/artyz7/flow/build.sh RES=1080p
```

Supported modes:

| RES | Pixel / serial clock | Notes |
|---|---:|---|
| `480p` | 25.1875 / 125.9375 MHz | safe first-light fallback (+497 ppm) |
| `800x600` | 40.000 / 200.000 MHz | VESA mode |
| `1024x768` | 65.000 / 325.000 MHz | Tang highest-clean edge comparison |
| `720p` | 74.21875 / 371.09375 MHz | direct Tang artifact comparison (-421 ppm) |
| `1080p` | 148.4375 / 742.1875 MHz | Full HD stress target (-421 ppm) |
| `1440p` | 240.000 / 1200.000 MHz | 2560x1440 reduced-blanking stress target at 59.58 Hz (-7030 ppm) |

Program the PL over JTAG:

```bash
openFPGALoader -b arty_z7_20 boards/artyz7/build/1080p/top_artyz7.bit
```

BTN0 resets the design. BTN1 cycles the 32 patterns. LED0 shows MMCM lock, LED1
shows HDMI hot-plug present, and LED2/LED3 expose pattern-select bits.

## Hardware Status

- `1080p` and `1440p` have been visually tested clean on an Arty Z7-20 with all
  32 patterns. The 1440p test used `ZONES=47`.
- The strict Vivado build gate checks setup/hold and critical/error DRCs. For
  the validated 1440p build, setup WNS was `0.313 ns`, hold WHS was `0.134 ns`,
  and critical/error DRC count was `0`.
- The full 1440p timing summary still reports an OSERDESE2 pulse-width/min-period
  violation on the 1200 MHz `serial_unbuf` clock. This is expected for the stress
  target and does not block bitstream generation, but it should stay visible in
  future 1440p bring-up notes.
- Pattern 25 (`LD1D_SWEEP`) is currently zone-stepped for timing closure: with
  `ZONES=47` it traverses the display in 256 frames, or about 4.3 s at 59.58 Hz.
  This can look fast and stepped on a 2560-wide panel. A slower frame phase is the
  next planned polish pass.

## Notes

- The top reuses `boards/common/dvi_tmds_encoder.sv`; Digilent `rgb2dvi` is only
  a clocking/serializer reference, not instantiated.
- DVI channel map is explicit: data channel 0 is blue plus `{vsync, hsync}`,
  channel 1 is green, and channel 2 is red.
- The TMDS clock lane is serialized through the same OSERDESE2 wrapper as the
  data lanes using `10'b1111100000`; build with `CLK_ALT=1` to flip that word.
- HDMI DDC and CEC are high-Z. The fixed-mode output is DVI-style video without
  EDID negotiation.

## Troubleshooting

If Vivado exits with:

```text
No parts matched 'xc7z020clg400-1'
```

the Vivado installation is missing Zynq-7000 device support. Re-run the Xilinx
installer's "Add Design Tools or Devices" flow and add Zynq-7000 devices, then
rerun the build. Changing `RES=` will not help until the part exists in Vivado.

References:

- Digilent Arty-Z7-20 master XDC:
  <https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Arty-Z7-20-Master.xdc>
- Digilent RGB-to-DVI user guide:
  <https://raw.githubusercontent.com/Digilent/vivado-library/master/ip/rgb2dvi/docs/rgb2dvi.pdf>
