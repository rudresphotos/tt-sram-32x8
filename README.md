![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg)

# SKY130 SRAM 32x8 (OpenRAM) for Tiny Tapeout

- [Read the documentation for project](docs/info.md)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Analog projects

For specifications and instructions, see the [analog specs page](https://tinytapeout.com/specs/analog/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)
  - Bluesky [@tinytapeout.com](https://bsky.app/profile/tinytapeout.com)

## How this layout was made

`gds/`, `lef/` and `verilog/` hold the finished tile. `build/` holds everything used to make it:

- `build/macro/`: the OpenRAM 32x8 SRAM (config `tt_sram_8x32_wpr1.py`, OpenRAM with `openram_dnwell_nwell5a.patch`),
  then `tools/fix_implants.py` (implant gap fill for the KLayout FEOL rules); macro LVS re-checked after the fix.
- `build/config.yaml`: LibreLane 3.0.14 run that places the SRAM in the 1x2 tile and routes it to the TT pins.
- `build/pdn/pdn_cfg.tcl`: power grid = two full-height met4 stripes (VGND, VPWR) that drop via3 onto the SRAM power ring.
- `build/openram_cells/`: fixed OpenRAM dummy cell `sky130_custom_dummy` (17 Nov 2026). The stock cell has two
  floating transistor gates and sits on every bitline through the replica wordline; one li1 rectangle ties those
  gates to ground. See `build/openram_cells/README.md`.

## Credits

- SRAM generated with [OpenRAM](https://github.com/VLSIDA/OpenRAM) (BSD-3-Clause), SKY130 cells from the
  SkyWater PDK and `sky130_fd_bd_sram` (Apache-2.0).
- OpenRAM baseline flow and verification scripts: the team's OpenRAM baseline repository.
- Tile integration, power grid and layout fixes for Tiny Tapeout: Rudr Bisht.
