# boards/artyz7/ - Tier 4 wrapper (Digilent Arty Z7-20, XC7Z020)

PL-only HDMI/DVI test-pattern output for the Arty Z7-20. The design uses the
board's 125 MHz PL oscillator, a 7-series MMCM, the existing reusable pattern
core, the project-owned DVI/TMDS encoder, OSERDESE2 10:1 serializers, and OBUFDS
TMDS outputs on the HDMI source connector J11.

## Build

This board uses Vivado. On this WSL2 machine the wrapper calls Windows Vivado
2025.1 from `/mnt/c/Xilinx/2025.1/Vivado/bin/vivado.bat`, stages the build under
`C:\Temp`, then copies reports and bitstreams back to `boards/artyz7/build/`.

```bash
./boards/artyz7/flow/build.sh                  # 1920x1080p60 default
./boards/artyz7/flow/build.sh RES=480p         # safe bring-up fallback
./boards/artyz7/flow/build.sh RES=720p         # Tang comparison mode
./boards/artyz7/flow/build.sh report           # last build summary
```

Supported first-pass modes:

| RES | Pixel / serial clock | Notes |
|---|---:|---|
| `480p` | 25.1875 / 125.9375 MHz | safe first-light fallback (+497 ppm) |
| `800x600` | 40.000 / 200.000 MHz | VESA mode |
| `1024x768` | 65.000 / 325.000 MHz | Tang highest-clean edge comparison |
| `720p` | 74.21875 / 371.09375 MHz | direct Tang artifact comparison (-421 ppm) |
| `1080p` | 148.4375 / 742.1875 MHz | Full HD stress target (-421 ppm) |

Program the PL over JTAG:

```bash
openFPGALoader -b arty_z7_20 boards/artyz7/build/1080p/top_artyz7.bit
```

BTN0 resets the design. BTN1 cycles the 32 patterns. LED0 shows MMCM lock, LED1
shows HDMI hot-plug present, and LED2/LED3 expose pattern-select bits.

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
