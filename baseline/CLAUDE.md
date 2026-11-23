# CLAUDE.md: handover notes for Claude Code

This repo is a custom SRAM for a Tiny Tapeout (TT) chip in SKY130. The OpenRAM baseline (16×8, stock cells) is
**done and verified**. Read `README.md` (status, layout, commands) first. Read `docs/sram_debug_log.md` before
debugging anything: it records two traps that already cost a day each.

## Where things run
* All EDA work runs in WSL2 Ubuntu (distro normally named `sram`); this repo lives at `~/sram_work`.
* Best: run Claude Code **inside WSL** from `~/sram_work`. If Claude runs on Windows instead, call commands as
  `wsl -d sram -e bash -c '...'`. Use `-e`, because with `--` the Windows-side shell expands `$vars`.
* Non-interactive shells don't load `~/.bashrc`. Run every EDA tool through `~/sram_work/nixrun <cmd>`, which
  sources Nix, sets OPENRAM_HOME / OPENRAM_TECH / PDK_ROOT, enters `nix develop` in `~/OpenRAM`, and returns to the cwd.
* External (not in the repo): `~/OpenRAM` (pinned commit + `openram/*.patch`, installed by `setup.sh`), and the PDK at `~/OpenRAM/sky130A` -> `~/.ciel`.

## Hard-won facts (don't re-derive them)
* **The reference is the PEX netlist** (`--netlist pex`). The schematic netlist has a wordline-glitch race
  (address DFF -> decoder beats the fall of `wl_en`) that the extracted layout does not have. Schematic failures are not real bugs.
* **The transient step is 0.1 ns** (default `--tstep`). ngspice uses it as the max step; 1 ns gave false write failures at sf.
* **In this PDK `sf` = fast NMOS / slow PMOS and `fs` = slow NMOS / fast PMOS** (measured Idsat). Don't trust the letter order.
* Magic writes `w=3u`, but the SKY130 models use `scale=1e-6`. `sim/prep_netlist.sh` strips the units; never feed a raw netlist to ngspice.
* PEX is capacitance + coupling only, with no wire resistance.
* The bitcell is `sky130_custom_cell` (6T, all W=0.42 L=0.15). The write driver only pulls down; the other bitline floats at precharge.

## Pro-plan friendly habits (context and time are limited)
* **Never read the big generated files** (`pex/sram_pex.spice` ~11 MB, `sim/netlist/*`, `sim/runs/*.log`, `*.dat`). Use `grep`, `head`, or `python3 sim/sramtb.py check <run>`.
* A march sim takes 40–55 min; `corners.sh` (7 corners) takes ~2 h. Run them in the background and wait for the notification instead of polling.
* Start with the quick test: `./corners.sh debug --glitch` (a few minutes) before any march.
* Write results into `docs/sram_debug_log.md` (append a section) so the next session doesn't redo work.

## What's next (the owner's plan)
1. **Characterize the stock cells** to get design specs: `sky130_fd_bd_sram__openram_dff`, `sky130_fd_bd_sram__openram_write_driver`, `sky130_fd_bd_sram__openram_sense_amp`
   (clk-to-Q, setup/hold, drive, sense-amp offset/delay, write time) at the 7 corners.
2. **Design a custom DFF first** and swap it in. If timing gets tight, the plan is to lower the clock (40 ns now) rather than redesign.
   The bitcell will **not** be replaced. Write driver / sense amp swaps are optional.
3. After each swap: `openram/generate.sh` (check DRC = 0, LVS match), `pex/extract.sh`, `sim/prep_netlist.sh`,
   `sim/corners.sh debug --glitch`, and `sim/corners.sh march`. All corners must stay 256/256.
4. **TT integration:** a `tt_um_*` analog-template wrapper. Draft pin map: `ui_in[3:0]`=addr, `ui_in[4]`=WEB0, `ui_in[5]`=CSB0,
   `uio[7:0]`=din, `uo_out[7:0]`=dout, `clk`=clk0. Also met4 power (no met5), placement in a 1×2 tile, and TT precheck
   (KLayout DRC + antenna, which may flag what Magic didn't).

## Repo hygiene
* Don't edit `macro/` by hand. It is OpenRAM output; regenerate it with `openram/generate.sh` (tested: DRC 0, LVS match).
  A regeneration is not byte-identical (subckt names/order change), so re-verify all corners before trusting it.
* OpenRAM must run with `~/OpenRAM/.venv/bin/python3` inside `nixrun` (numpy etc. are there, not in the Nix venv).
* Don't put files inside `~/OpenRAM`; everything we add belongs in this repo.
* New run outputs go to `sim/runs/` (git-ignored). Copy only final evidence logs into `sim/results_*/`.
