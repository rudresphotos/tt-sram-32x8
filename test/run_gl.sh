#!/usr/bin/env bash
# Gate-level check of the finished tile: LibreLane final netlist + OpenRAM behavioural SRAM model (iverilog).
# usage: PDK_ROOT=<ciel sky130 version dir> NETLIST=<final pnl.v> ./run_gl.sh
set -euo pipefail
cd "$(dirname "$0")"
V="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog"
iverilog -g2012 -DUSE_POWER_PINS -DFUNCTIONAL -DUNIT_DELAY=#1 -o tb_gl.vvp tb_gl.v "$NETLIST" \
  ../build/macro/tt_sram_8x32_wpr1.v "$V/primitives.v" "$V/sky130_fd_sc_hd.v"
vvp -n tb_gl.vvp | grep -E "gate-level|BAD"
