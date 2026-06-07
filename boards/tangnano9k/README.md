# boards/tangnano9k/ — Tier 4 wrapper (placeholder, implemented in M2)

Sipeed Tang Nano 9K (Gowin GW1NR-9C) board wrapper. **Not portable** — this is
where all vendor-specific logic lives.

M2 adds:
- **Clocking:** `rPLL` → 5× serial clock; `CLKDIV` ÷5 → pixel clock.
- **HDMI/DVI PHY:** DVI 8b/10b TMDS encoders → `OSER10` 10:1 serializers →
  `TLVDS_OBUF` for 3 data + 1 clock pairs. *(Verify the exact primitive recipe
  against current Gowin docs — PRD §22.)*
- **Constraints:** `.cst` (pins) + `.sdc` (timing).
- **Control:** onboard button → `gpio_button_ctrl` → `pattern_sel`.
- **Top:** instantiates the Tier 1 VTG + Tier 0 pattern core, drives HDMI.

**Resolution:** compile-time fixed via `RESOLUTION` (target `1920x1080p60`).
Bring-up ladder: `640x480p60` → `1280x720p60` → `1920x1080p60`; 720p60 is the
must-pass milestone (1080p60 ≈ 742.5 MHz serial is aggressive on the open flow —
PRD §11, §18).

Open toolchain: Yosys + nextpnr-himbaechel (Project Apicula) + `gowin_pack`;
vendor alternative: Gowin EDA.
