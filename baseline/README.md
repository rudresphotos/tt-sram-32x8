# Custom SRAM for Tiny Tapeout (SKY130): OpenRAM baseline

A 16-word × 8-bit SRAM macro made with OpenRAM from stock SKY130 cells. It is verified on the extracted layout
and meant as the baseline before cells are swapped for custom ones and the macro is integrated into Tiny Tapeout.

## Status (2026-11-13)

| Item | State |
|---|---|
| Macro `sky130_sram_0kbytes_1rw_8x16_8` (GDS, LEF, Verilog, SPICE) | done, in `macro/` |
| Size | 128 bits; array 17 rows × 9 cols (incl. spare + replica); ~133 × 146 µm |
| DRC (Magic) / LVS (Netgen) | 0 errors / match (OpenRAM's own run, see `macro/*.log`) |
| Function, extracted layout (C only), 40 ns clock | **256/256 bits pass at all 7 corners** (tt25, ff-40, ff100, ss-40, ss100, fs25, sf25) |
| Wordline glitch check | ≤ 0.02 V at all corners |
| Custom cells | not started. Plan: keep the stock bitcell; characterize the stock DFF / write driver / sense amp, then design a custom DFF first |
| Tiny Tapeout integration | not started (`tt_um_*` wrapper, met4 power, 1×2 tile, TT precheck with KLayout DRC) |

The full story of how the baseline was debugged (a schematic-only race, a simulator step artifact) is in
[docs/sram_debug_log.md](docs/sram_debug_log.md). **Read sections 1 and 5 before changing anything.**

## Setup (once, ~1–2 h, mostly downloads)

Needs Windows 10/11 with WSL2 (or native Ubuntu 24.04), ≥ 8 GB RAM, ~15 GB free disk.

1. In Windows PowerShell, create an Ubuntu 24.04 WSL distro named `sram` and open it:
   ```powershell
   wsl --install -d Ubuntu-24.04 --name sram
   wsl -d sram
   ```
   (If your WSL is too old for `--name`, run `wsl --update` first.)
2. Inside WSL, clone **to exactly `~/sram_work`** (the scripts assume that path) and run the setup:
   ```bash
   git clone <this repo URL> ~/sram_work
   cd ~/sram_work && ./setup.sh
   ```
   It installs Nix, OpenRAM (pinned commit + one patch), the SKY130 PDK, and finishes with a smoke test that should end in `PASS`.

## Repository layout

```
setup.sh                  one-time toolchain install + smoke test
nixrun                    run any command inside OpenRAM's Nix shell (magic, netgen, ngspice, klayout) in the current dir
CLAUDE.md                 handover notes for Claude Code (read automatically)
openram/
  sky130_sram_1rw_8x16.py               the OpenRAM config (16x8, 1 rw port, sky130 custom cell)
  sram_py_skip_characterization.patch   OpenRAM patch: delay stimulus, .lib characterization and datasheet only warn instead of aborting (they failed for this config; that's why the .lib is empty)
  generate.sh                           regenerate the macro with OpenRAM and copy it into macro/
  requirements-venv.txt                 pinned Python packages for ~/OpenRAM/.venv (setup.sh installs them)
macro/                    OpenRAM output, the baseline design (GDS, LEF, .v, .sp, log with DRC/LVS)
pex/
  extract.sh, run_pex.sh  GDS -> netlist with parasitic capacitance (Magic)
sim/
  sramtb.py               testbench generator + checker (tests: march, debug, wtoggle; corners; glitch check; waveform dumps)
  run.sh                  generate + simulate + check, one run
  corners.sh              one test at all 7 corners on the extracted netlist, 3 in parallel
  prep_netlist.sh         builds sim/netlist/ (unit fixes, probe nodes) from macro/ and pex/
  cellwrite.py            single-bitcell write test
  results_baseline/       logs of the final baseline runs (the evidence for the status table)
docs/sram_debug_log.md    debug history, results tables, caveats
```
Generated (git-ignored): `sim/runs/`, `sim/netlist/`, `pex/work/`, `pex/sram_pex.spice`.
The `macro/run_*.sh` files are OpenRAM's own scripts and contain the original author's paths; our flow does not use them.

## Everyday commands (inside WSL)

```bash
cd ~/sram_work/sim
./prep_netlist.sh                         # after re-extraction
./run.sh march --netlist pex              # 256-bit all-address test on the layout, tt 25C (~45 min)
./corners.sh march                        # same at all 7 corners (~2 h, 3 in parallel)
./corners.sh debug --glitch               # quick test + wordline glitch check at all corners
./run.sh wtoggle --netlist pex --corner sf --dump && python3 sramtb.py wave wtoggle_pex_sf25C
python3 sramtb.py --help
```
After changing the design: `openram/generate.sh`, then `pex/extract.sh`, then `sim/prep_netlist.sh`, then `sim/corners.sh debug --glitch` and `sim/corners.sh march`.
Note: re-running OpenRAM gives a DRC/LVS-clean macro, but not byte-identical to the committed one (internal subcircuit names/order change). The committed `macro/` is the version verified at all corners; anything regenerated must be re-verified.

## Rules learned the hard way

* Judge function on the **extracted (PEX) netlist** only. The schematic netlist has a wordline race that does not exist in the layout.
* Keep the transient step at **0.1 ns** (the default). A 1 ns step produced false write failures at the sf corner.
* In this PDK `sf` = fast NMOS / slow PMOS and `fs` = slow NMOS / fast PMOS (measured).
* After any cell swap, re-run the glitch check and the march test at all corners. A new DFF changes the address-path timing.
