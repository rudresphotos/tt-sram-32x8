# Timing sign-off: tt_um_rudresphotos_sram (TT SKY130, 1x2 tile, TTSKY26e)

Status: __STATUS__

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

__D2__

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

__D3SETUP__

## 5. Results per corner

__RESULTS__

## 6. Worst paths in words

__PATHS__

## 7. How to reproduce

```bash
make tile                       # OpenRAM macro -> fix_implants -> LibreLane -> gate-level test -> TT precheck
flow/characterize.sh TT         # also SS, FF: ngspice .lib into build/macro/lib/
flow/sta.sh repro               # LibreLane sign-off STA with the macro .lib, report in build/sta/repro/sta_summary.md
```

In CI: `reproduce tile` workflow (every push to `flow/*`), `characterize macro` workflow (pushes to `char/*`).

## 8. Limits of this sign-off

__LIMITS__
