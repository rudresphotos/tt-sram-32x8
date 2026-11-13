# SRAM 16x8 (OpenRAM, SKY130): debug log and simulation environment

Last updated: 2026-11-12. This file documents every debug action taken on the macro
`sky130_sram_0kbytes_1rw_8x16_8` and how to reproduce each result.

---

## 1. Verdict

| Question | Answer |
|---|---|
| Does the generated layout (GDS) work? | **Yes.** In simulation of the extracted layout at a 40 ns clock, all 256 bits pass at every corner (see section 4). |
| Why did the first all-address test fail? | A timing race that appears only in the **schematic** netlist, which has no wire capacitance (section 3.4). |
| Why did the sf corner fail at first? | A **simulator accuracy artifact**: a 1 ns max time step skipped fast events. With 0.1 ns it passes (section 3.7). |
| Rules going forward | Judge function on the **PEX** netlist only, and always use the **0.1 ns** step (now the default). Re-check every corner plus the glitch check after each cell swap. |

---

## 2. Clean environment: where everything lives (WSL distro `sram`)

```
~/OpenRAM/                         OpenRAM checkout, commit 2f7b386 (1.2.50). Only local change: compiler/sram.py
  macros/sram_configs/sky130_sram_1rw_8x16.py   our config (copied from the repo's openram/)
  macros/macro/sky130_sram_0kbytes_1rw_8x16_8/  OpenRAM OUTPUT ONLY (GDS, LEF, .v, .sp, ...)

~/sram_work/                       THE GIT REPO: everything we add lives here, separate from OpenRAM
  setup.sh, README.md, CLAUDE.md   one-time install / human overview / Claude handover
  openram/                         config, sram.py patch, generate.sh (OpenRAM -> macro/)
  macro/                           committed copy of the OpenRAM output (the scripts read this one)
  docs/sram_debug_log.md           this file
  nixrun                           run any command in the OpenRAM nix shell + env vars, in the cwd
  pex/
    extract.sh                     GDS -> sram_pex.spice (layout netlist with parasitic C)
    run_pex.sh                     Magic script (copy of OpenRAM run_ext.sh with C + coupling on)
    run_pex.log                    last extraction log
    sram_pex.spice                 extracted netlist (raw Magic output)
    work/                          Magic scratch (.mag/.ext), safe to delete
  sim/
    .spiceinit                     ngspice settings (hsa mode, 4 threads)
    prep_netlist.sh                builds netlist/ from OpenRAM + pex outputs (unit fixes, probes)
    sramtb.py                      testbench generator + checker (tests, corners, glitch, dumps)
    run.sh                         one-shot: gen + simulate + check
    corners.sh                     run a test on the PEX netlist at all corners, 3 in parallel
    cellwrite.py                   cell-level write test (1 bitcell + write-driver pull-down)
    netlist/                       generated netlists (never edit by hand)
      sram_tb.sp                   schematic netlist, unit-fixed
      sram_pex.spice               PEX netlist, unit-fixed
      sram_pex_probe.spice         PEX + probe nodes: xsram.wlp0..16, wlenp, wenp, senp, penp, rblp, blp, brp
    runs/<run>.{sp,json,log,dat}   one set per simulation run
    runs/coarse_1ns/               superseded runs made with the 1 ns step (kept for the record)
    runs/sf_investigation/         cellwrite_*, idsat_* and schematic sf dump from section 3.7
    results_baseline/              final march + glitch logs/json for section 4 (committed evidence)
    archive_day1/                  first-day hand-made testbenches (original machine only, not in git)
```
`runs/`, `netlist/`, `pex/work/` and `pex/sram_pex.spice` are git-ignored; the scripts regenerate them.

### Everyday commands

```bash
cd ~/sram_work/sim
./prep_netlist.sh                         # after any OpenRAM regeneration / re-extraction
./run.sh march --netlist pex              # full 256-bit all-address test on the layout (~30-40 min)
./corners.sh march                        # same at all 7 corners, 3 in parallel
./corners.sh debug --glitch               # quick 6-cycle test + wordline glitch check at all corners
./run.sh wtoggle --netlist pex --corner sf --dump    # write test + waveforms; then:
python3 sramtb.py wave wtoggle_pex_sf25C
python3 sramtb.py --help
```
After changing the design: `~/sram_work/openram/generate.sh` (OpenRAM -> macro/), then `~/sram_work/pex/extract.sh`, then `./prep_netlist.sh`.

Tests: `march` (all 16 addresses, 2 data patterns, 256 bit checks), `debug` (6 cycles),
`wtoggle` (flip every bit of addr 0 and 5 seven times, 112 checks).
Corners: tt, ff, ss, fs, sf (SKY130 lib sections) with any `--temp`.
**Note:** in this PDK `sf` = fast NMOS / slow PMOS, and `fs` = slow NMOS / fast PMOS (measured, section 3.7).

---

## 3. Debug timeline: what was done and why

### 3.1 Symptom
* The first random test (OpenRAM's own stimulus) used only addresses 0 and 15 and passed.
* The all-address march test failed with 55 of 256 bits wrong. Failing reads returned the data of the address accessed one cycle earlier.
* With a 4x slower clock (40 ns), 47 of 256 bits were still wrong, so it isn't a speed problem.

### 3.2 Workspace cleanup
* Moved every file we had created out of the OpenRAM output folder into `~/sram_work/sim/archive_day1/`.
  Nothing was deleted, and OpenRAM's outputs were not touched.
* Replaced the ad-hoc scripts with `sramtb.py`, `prep_netlist.sh`, `run.sh` and `corners.sh`.
* Added `~/sram_work/nixrun`. Non-interactive shells don't load `~/.bashrc`, so `PDK_ROOT` etc. were missing,
  and `nix develop` must start from `~/OpenRAM`.

### 3.3 Decoder check (netlist review)
* The 2-to-4 and 3-to-8 predecoders feed and2 gates that produce decode_0..16. The logic is correct, and the NAND cell sizes are sane.
* An early wordline probe reported "two rows high" every cycle. **That was a probe artifact**: the window opened
  5 ps after the clock edge, while the previous row was still turning off.

### 3.4 Root cause 1: wordline glitch race (schematic only)
Waveform dump (`debug` test, schematic): write addr 0 = 0x0F, write addr 1 = 0xF0, read 0, read 1. Probed the control
signals, wordlines 0/1, bitlines, dout, and the **stored node Q of cells r0c0 and r1c0**.
* Row 1 was written correctly: Q(r1c0) = 0 from 105 to 160 ns.
* At the edge at ~160.6 ns (read 0 to read 1), the address flops switch the decoder to row 1 about 0.1 ns **before `wl_en`
  turns off**. Wordline 1 glitches to **2.08 V** while the bitlines still hold row 0's read data, so row 0's data is copied into row 1.
* Race path (`control_logic_rw`):
```
clk -> clk_buf -+-> row_addr_dff -> predecoder -> and2_dec -> wordline_driver(NAND with wl_en) -> wl
                +-> inv -> pand2 (gated_clk_bar) -> pdriver_1 -> wl_en -------^
```

### 3.5 Is the race real? Parasitic extraction (PEX)
* The layout uses the same bitcell as the simulation (`sky130_custom_cell`, all transistors W=0.42 um).
* Copied OpenRAM's `run_ext.sh` and turned on capacitance + coupling with flat output: 5687 parasitic capacitors, 2631 transistors.
  (OpenRAM's own version extracts without capacitance, for LVS only.) Re-extraction is reproducible (same devices and capacitors; Magic may list the capacitors in a different order).
* Magic writes `w=3u`, `ad=0.42p`, but the SKY130 models use `scale=1e-6`, so `prep_netlist.sh` strips those units.
* Port order differs between the netlists, and `sramtb.py` handles both.

### 3.6 Glitch detector
`--glitch` measures the peak of every wordline in the 3 ns after each rising clock edge, excluding the row legitimately
on in the previous cycle and the first edge (flop states are undefined before it).
Schematic: 2.08 V. **PEX: at most 0.02 V at all 7 corners.** The race does not exist in the layout.

### 3.7 Root cause 2: the sf-corner "failure" was a simulator artifact
* First corner run (1 ns step): every corner passed except **sf 25C, with 186/256 bits wrong**. Pass 2 read back pass-1 data, so writes were not taking.
* Hypothesis A, "the cell is too hard to write at sf": **rejected.**
  * `cellwrite.py` (one bitcell, the write-driver pull-down, and the extracted 19.6 fF bitline C) writes at every corner with a wordline pulse of 0.1 ns or more.
  * A direct Idsat measurement showed this PDK's `sf` is **fast NMOS (249 uA vs tt 197) / slow PMOS (52 vs 85 uA)**, the easiest corner for writing.
* Hypothesis B, "the precharge is too slow at sf": **rejected.** A PEX waveform dump at sf showed both bitlines recovering to 1.83 V each cycle.
* That dump run (0.1 ns step) **passed**, while the identical test with a 1 ns step had failed 72/112.
  * ngspice uses the `.tran` step as the maximum time step, and 1 ns was too coarse for sub-ns write events at this corner.
  * Re-running at 0.1 ns: write test sf **112/112 PASS**.
* The 0.1 ns step is now the default. All march corners were re-run with it (section 4), and the 1 ns runs moved to `runs/coarse_1ns/`.

---

## 4. Results

### 4.1 Final baseline: PEX netlist, 40 ns clock, 0.1 ns step, march test (256 bit checks)

| Corner | tt 25C | ff -40C | ff 100C | ss -40C | ss 100C | fs 25C | sf 25C |
|---|---|---|---|---|---|---|---|
| Bits correct | 256/256 | 256/256 | 256/256 | 256/256 | 256/256 | 256/256 | 256/256 |
| Result | PASS | PASS | PASS | PASS | PASS | PASS | PASS |
| Sim time | 2845 s | 3217 s | 2814 s | 2570 s | 2488 s | 2408 s | 1815 s |

Run files: `runs/march_pex.*` (tt) and `runs/march_pex_<corner><temp>C.*`. Supporting result: `wtoggle` on PEX at sf 25C, 112/112 PASS.

### 4.2 Wordline glitch check: PEX, `debug --glitch`, 0.1 ns step

| Corner | tt 25C | ff -40C | ff 100C | ss -40C | ss 100C | fs 25C | sf 25C |
|---|---|---|---|---|---|---|---|
| Worst glitch | 0.01 V | 0.01 V | 0.02 V | 0.01 V | 0.01 V | 0.02 V | 0.01 V |
| Reads | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 | 16/16 |

A cell needs roughly >0.4-0.5 V on its wordline before it is disturbed.

### 4.3 Historical / superseded runs
| Run | Netlist | Step | Result | Meaning |
|---|---|---|---|---|
| march 10 ns clock, day 1 | schematic | 1 ns | 55/256 wrong | schematic race |
| march 40 ns clock, day 1 | schematic | 1 ns | 47/256 wrong | schematic race |
| debug_sch_glitch | schematic | 0.1 ns | 8/16 wrong, 2.08 V glitch | race confirmed |
| march corners | PEX | 1 ns | all pass except sf 186/256 | sf = step artifact |
| wtoggle sf | PEX | 1 ns vs 0.1 ns | 72/112 wrong vs 0/112 | artifact confirmed |
| march 10 ns clock | PEX | 1 ns | cancelled | not needed: TT clock is user-chosen, 40 ns is the target |

---

## 5. Open items / caveats
* The PEX here has **capacitance only, no wire resistance**. For a 133x146 um macro that is a minor risk.
* Simulation only; no Monte-Carlo mismatch (the `*_mm` corners exist in the PDK if needed later).
* The schematic netlist is **not** a valid functional reference for this macro.
* When swapping in your own cells, re-run `./corners.sh debug --glitch` and `./corners.sh march`.
  The DFF in particular changes the address-path timing behind the race in 3.4.
* The OpenRAM `.lib` timing file is empty (characterization was bypassed in `compiler/sram.py`).
* Note: re-running OpenRAM gives a DRC/LVS-clean macro, but not byte-identical to the committed one (internal subcircuit names/order change). The committed `macro/` is the version verified at all corners; anything regenerated must be re-verified.
* Not yet done for Tiny Tapeout: the `tt_um_*` wrapper, met4 power hookup, tile placement and the TT flow.
