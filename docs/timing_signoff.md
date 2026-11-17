# Timing sign-off: tt_um_rudresphotos_sram (TT SKY130, 1x2 tile, TTSKY26e)

Status: **Timing MET at all 9 corners (setup and hold) for the current macro** (the try9 macro, rebuilt in D1).
Worst setup slack +6.888 ns, worst hold slack +7.551 ns. Not clean: 8 max-capacitance and up to 13 max-slew
violations at the macro pins, all at the edge of the characterized .lib range (section 5, 8).
This is the D4 report for the *current* macro; the final macro (write-timing fix + new sense amp) is not built yet,
so D1-D3 must be re-run on it (section 7: three commands) and this file updated.

Every number below is copied from a tool run; the run and the file are named next to it. Commands to redo all of
it are in section 7.

## 1. What is being signed off

The tile is just wires around one OpenRAM SRAM macro (`tt_sram_8x32_wpr1`, 32 words x 8 bits, plus a spare row and
column). There are no flip-flops in the wrapper, so every timed path either enters the macro or leaves it:

| Path | From | To | Timed against |
|---|---|---|---|
| address / control in | `ui_in[6:0]` pins (`csb`, `web`, `addr`) | macro `csb0`, `web0`, `addr0` | macro setup/hold vs the **rising** edge of `clk0` |
| write data in | `uio_in[7:0]` pins | macro `din0` | macro setup/hold vs the **rising** edge of `clk0` |
| spare in | `ui_in[7]` | macro `spare_wen0`, `addr0[5]`, `din0[8]` | same |
| read data out | macro `dout0[7:0]` | `uo_out[7:0]` pins | macro clk->dout (launched on the **falling** edge, see the .lib) + output delay |
| clock | `clk` pin | macro `clk0` | (clock network, no buffers) |

Setup = data must arrive *before* the capturing clock edge minus the setup time (checked at the slow corner,
"max" paths). Hold = data must not change too soon *after* the edge (checked at the fast corner, "min" paths).

## 2. Macro timing model (D2)

Made by `flow/characterize.sh` with OpenRAM v1.2.50's own characterizer (`sram_char.py`), **ngspice-45 transistor
simulation, not the analytical model**, on OpenRAM's LVS-clean schematic netlist of the macro (same 64 subcircuits as
Rudr's try9 `.sp`). CI run 44034295552 (`6780eb7`), one job per corner; OpenRAM reports `Characterization:` TT 6441.9 s, SS 5062.2 s, FF 5094.6 s.
Files: `build/macro/lib/tt_sram_8x32_wpr1_{TT_1p8V_25C,SS_1p6V_100C,FF_1p95V_-40C}.lib`, OpenRAM logs in
`build/macro/lib/char_logs/`.

| Corner (LibreLane name) | clk0 -> dout0 delay | setup (vs clk0 rise) | hold (vs clk0 rise) | min period (OpenRAM) | s_en after clk fall (one probe) |
|---|---|---|---|---|---|
| TT 1.80 V 25 C (`tt_025C_1v80`) | 1.205 - 2.072 ns | 0.090 - 0.505 ns | -0.300 - 0.481 ns | 4.219 ns | 1.902 ns |
| SS 1.60 V 100 C (`ss_100C_1v60`) | 2.087 - 3.877 ns | 0.139 - 0.383 ns | -0.374 - -0.081 ns | 7.812 ns | 3.578 ns |
| FF 1.95 V -40 C (`ff_n40C_1v95`) | 0.702 - 1.276 ns | 0.066 - 0.652 ns | -0.105 - 0.505 ns | 2.578 ns | 1.194 ns |

(ranges = min..max over the 3x3 table; `flow/lib_sanity.py` output; s_en = last `s_en delay=` line of each char log.)

How to read it:
- Units: time `1ns`, capacitance `1pF` (checked by lib_sanity.py). Tables are 3x3: input slew 0.05 / 0.2 / 0.8 ns
  x output load 3.445 / 13.78 / 55.12 fF.
- Inputs (`addr0`, `din0`, `csb0`, `web0`, `spare_wen0`) have setup/hold against the **rising** edge of `clk0`
  (they go into the macro's input flip-flops). Hold is mostly negative: data may even change slightly before the edge.
- `dout0` is a `falling_edge` arc: the read happens in the clock-low half, so data comes out after the **falling**
  edge (half a cycle = 20 ns into the 40 ns cycle).
- Plausible? Corner order is right (FF fastest, SS slowest; SS/FF clk->dout ratio about 3), every value is far
  inside the 40 ns cycle. Against Rudr's PEX transistor sims (README section 6): sense enable there fires 2-3 ns
  after the falling edge; here 1.2-3.6 ns after it. This .lib uses the schematic netlist (no wire parasitics), so
  it should be a little faster than PEX, which is what we see at TT (1.9 ns vs 2-3 ns).

Flow fixes needed to get OpenRAM's characterizer to run on this sky130 macro (none touches the circuit; details and
evidence in `docs/flow_LOG.md` entries 17-22): the generator's own characterizer stops at
`Could not find bl net in timing paths` (also in Rudr's try9 log - the real reason for the skip-characterization
patch), so the stand-alone `sram_char.py` is used; the bitcell storage nets are `Q`/`Qbar`; 6 transistors of
`sky130_custom_nand3_dec` are written in microns (`W=0.74u`) while the PDK sets `.option scale=1.0u`;
`s_en` must be probed at the SRAM top-level net; ngspice-45 aborts the DFF setup/hold deck at 10 ps max step;
`sram_char.py` needs the macro size and has a `print_time` NameError.

## 3. Constraints (TT I/O assumptions)

Tiny Tapeout's project template (`TinyTapeout/ttsky-verilog-template` `src/config.json`, commit `a42e666`) sets
`CLOCK_PERIOD` and `CLOCK_PORT` but no I/O delays, and tt-support-tools (`9d13ff3`, the commit used for precheck)
has no SDC or I/O-delay setting either (searched the whole tree). So TT tiles are signed off with LibreLane's own
default SDC, `librelane/scripts/base.sdc` in LibreLane 3.0.14, with these values (from the try9 `resolved.json`,
unchanged in this flow):

| SDC command (base.sdc) | Variable | Value | Meaning here |
|---|---|---|---|
| `create_clock` | `CLOCK_PERIOD` | 40 ns | 25 MHz on `clk` |
| `set_input_delay` | `IO_DELAY_CONSTRAINT` | 20 % of 40 ns = 8 ns | TT's input mux/routing may take 8 ns after the clock edge |
| `set_output_delay` | `IO_DELAY_CONSTRAINT` | 8 ns | outputs must be valid 8 ns before the next rising edge |
| `set_driving_cell` | `SYNTH_DRIVING_CELL` | `sky130_fd_sc_hd__inv_2/Y` | what drives each input pin |
| `set_load` | `OUTPUT_CAP_LOAD` | 33.442 fF | load on each output pin |
| `set_clock_uncertainty` | `CLOCK_UNCERTAINTY_CONSTRAINT` | 0.25 ns | jitter/skew margin |
| `set_clock_transition` | `CLOCK_TRANSITION_CONSTRAINT` | 0.15 ns | clock slew at the pin |
| `set_timing_derate` | `TIME_DERATING_CONSTRAINT` | 5 % (early 0.95, late 1.05) | on-chip variation margin |
| limits | `MAX_TRANSITION_CONSTRAINT` / `MAX_CAPACITANCE_CONSTRAINT` / `MAX_FANOUT_CONSTRAINT` | 0.75 ns / 0.2 pF / 10 | design-rule checks |

## 4. STA set-up (D3)

- Tool: LibreLane 3.0.14's own sign-off STA step `OpenROAD.STAPostPNR` (OpenSTA), re-run by `flow/sta.sh` on the
  finished tile run. Nothing is re-placed or re-routed, so the timed layout is the D1 layout (= try9).
- Corners: LibreLane's 9 STA corners = {nom, min, max} parasitics x {tt_025C_1v80, ss_100C_1v60, ff_n40C_1v95}.
  Standard cells: `sky130_fd_sc_hd` .lib of that corner. Wires: the run's extracted SPEF for that corner.
  Macro: the D2 .lib of the matching PVT corner (`MACROS.tt_sram_8x32_wpr1.lib` in `build/config_sta.yaml`).
- Changed against try9's STA: (1) the macro now has a .lib per corner; (2) `STA_MACRO_PRIORITIZE_NL: false`, so
  LibreLane uses that .lib for the macro rather than looking for a gate-level netlist of it. In try9 the macro had
  no .lib (`MACROS ... "lib": {}` in try9 `resolved.json`) and OpenSTA logged
  `module tt_sram_8x32_wpr1 not found. Creating black box for mem.` (try9 `55-openroad-stapostpnr/sta.log`).
  A black box has no timing arcs, so every path ended at the macro unconstrained. That is why try9's summary shows
  setup/hold worst slack `1000000…` (= "no constrained path"), not a real pass.
- Constraints: section 3 (LibreLane `base.sdc`), unchanged.

## 5. Results per corner

From `docs/sta/sta_summary_ci.md` (CI run 44049111747, `d34a65f`, step `OpenROAD.STAPostPNR` re-run by
`flow/sta.sh`; `sta.log`: macro **not** black-boxed). Slack in ns; positive = met.

| corner | setup WS | setup TNS | hold WS | hold TNS | max slew vio | max cap vio |
|---|---|---|---|---|---|---|
| nom_tt_025C_1v80 | 9.343 | 0 | 7.612 | 0 | 0 | 8 |
| min_tt_025C_1v80 | 9.398 | 0 | 7.625 | 0 | 0 | 8 |
| max_tt_025C_1v80 | 9.295 | 0 | 7.600 | 0 | 0 | 8 |
| nom_ss_100C_1v60 | 6.997 | 0 | 7.571 | 0 | 11 | 8 |
| min_ss_100C_1v60 | 7.114 | 0 | 7.591 | 0 | 11 | 8 |
| max_ss_100C_1v60 | **6.888** | 0 | **7.551** | 0 | 13 | 8 |
| nom_ff_n40C_1v95 | 10.235 | 0 | 7.648 | 0 | 0 | 8 |
| min_ff_n40C_1v95 | 10.279 | 0 | 7.658 | 0 | 0 | 8 |
| max_ff_n40C_1v95 | 10.197 | 0 | 7.638 | 0 | 0 | 8 |

Setup and hold: **met** at every corner, 0 violating paths (`timing__setup_vio__count = 0`,
`timing__hold_vio__count = 0`).

Design-rule violations (`docs/sta/checks_*.rpt`), **not met, explained**:
- max capacitance, 8 at every corner: `mem/dout0[0..7]`, load 0.070-0.082 pF vs limit 0.05512 pF (SS numbers).
  The limit is not an electrical rule of the macro: OpenRAM writes `max_capacitance` = the largest load it
  characterized (55.12 fF, my table choice). The real load is TT's output-pin load from the SDC (33.442 fF) plus the
  route to the `uo_out` pin. Consequence: the clk->dout delay at these loads is **extrapolated** from the table.
- max slew at SS: the same 8 `dout0` pins, 0.789-0.913 ns vs the .lib's `default_max_transition : 0.5` (same
  cause: more load than characterized); and 5 macro inputs at 0.753-0.844 ns vs 0.75 (LibreLane
  `MAX_TRANSITION_CONSTRAINT`) / 0.8 (macro .lib): `din0[0]`, `din0[1]`, and `din0[8]`, `spare_wen0`, `addr0[5]`,
  which are all one net from `ui_in[7]` (fanout 3), driven by the SDC's `inv_2` model of the TT input.
- Fix for the first two: re-characterize with a larger load range (one line in
  `flow/openram/char_tt_sram_8x32_wpr1.py`, `load_scales`, e.g. up to 16 x 6.89 fF = 110 fF) and re-run STA.
  With 6.9 ns of setup slack the extrapolated delays would have to be off by more than 6.9 ns to matter.

## 6. Worst paths in words

All 234 reported constrained paths are one of two kinds (`docs/sta/sta_summary_ci.md` lists the 10 worst of each):

**Setup (worst 10 are all `mem` -> `uo_out[*]`, SS corner).** Worst: `max_ss_100C_1v60`, `mem/dout0[6]` ->
`uo_out[6]`, slack +6.888 ns. In words: the read data is launched by the **falling** clock edge at 20 ns; the clock
reaches `mem/clk0` at 20.224 ns; the macro's clk->dout at this corner and load is 4.623 ns (extrapolated, see above)
so `uo_out[6]` is valid at 24.862 ns. TT's harness needs it 8 ns (output delay) before the next rising edge at 40 ns,
minus 0.25 ns uncertainty = 31.750 ns. 31.750 - 24.862 = 6.888 ns to spare. The other 9 are the other `dout` bits at
SS (6.900-7.008 ns); they differ only by routing.

**Hold (worst 10 are all `ui_in[*]` -> `mem` address/data pins).** Worst: `max_ss_100C_1v60`, `ui_in[4]` ->
`mem/addr0[4]`, slack +7.551 ns. In words: TT changes the inputs 8 ns after the rising edge (input delay), the
new value reaches the macro pin at 8.081 ns; the macro needs the old value held until 0.361 (clock arrival)
+ 0.25 (uncertainty) - 0.081 (library hold) = 0.530 ns. 8.081 - 0.530 = 7.551 ns. Hold is easy here because the
TT input delay (8 ns) is much larger than any hold requirement.

Input setup paths (`ui_in`/`uio_in` -> macro inputs, captured on the next rising edge) have even more slack:
they arrive at ~8.1 ns and must be there by ~39.5 ns.

## 7. How to reproduce

```bash
make tile        # D1: OpenRAM macro -> fix_implants -> LibreLane -> gate-level test -> TT precheck
make lib         # D2: ngspice .lib at TT/SS/FF into build/macro/lib/ (about 1.5 h per corner)
make sta         # D3: LibreLane sign-off STA with the macro .lib -> build/sta/repro/sta_summary.md
```

Evidence run with everything together: https://github.com/AaryanSharmaCodes/tt-sram-32x8/actions/runs/44050957597
(macro, tile, try9 compare, TT precheck, STA all `success`).

In CI (free GitHub runners): `reproduce tile` (every push to `flow/*`: macro, tile, try9 compare, both prechecks,
STA with the committed .lib) and `characterize macro` (pushes to `char/*`: the three corners in parallel).

## 8. Limits of this sign-off

1. **Not the final macro.** Rudr's write-timing fix and new sense amp change the macro; re-run `make tile`, the
   characterization (push to a `char/*` branch) and `make sta`, then update sections 2, 5, 6.
2. **Schematic netlist, no wire parasitics** in the .lib (OpenRAM's characterizer does not support the PEX
   netlist for this config). Real delays are somewhat longer. The setup margin (6.9 ns) is large compared with that.
3. **Extrapolated clk->dout on the `uo_out` nets** (load 70-82 fF > 55 fF table edge), see section 5.
4. **Input pin capacitance** in the .lib (6.89 fF on every input) is OpenRAM's technology constant (`dff_in_cap`),
   not a simulated value.
5. **Characterized on one probed bit** (address 31, bit 7), as OpenRAM does; the .lib does not model the
   data-dependent write failure at ff -40 C or the sense-amp read failure at sf 25 C found in Rudr's PEX corner sims
   (`context/corner_diagnosis_LOG.md`). Those are functional problems of the macro, being fixed by Rudr; STA cannot
   see them. (OpenRAM's FF characterization wrote and read bit 7 correctly on the schematic netlist.)
6. **TT I/O delays** are LibreLane's defaults (20 % of the period), because TT's template sets none; TT's real
   input mux/output path is not modelled beyond that.
7. OpenRAM picks `min period` 4.219 / 7.812 / 2.578 ns by its own read/write test; the tile runs at 40 ns.
