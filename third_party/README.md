# third_party/

Isolation directory for any **permissively licensed** code that is ever vendored
into this repo.

Policy (PRD §20–§21, [PROVENANCE.md](../PROVENANCE.md)):
- Nothing here may be imported into `rtl/reusable/` (the portable, clean-room
  tree).
- Each vendored file keeps its **original license header**; add a `LICENSE` and
  a note in `PROVENANCE.md`.
- **No LGPL/copyleft** HDL, here or anywhere.

Currently empty — the design is clean-room.
