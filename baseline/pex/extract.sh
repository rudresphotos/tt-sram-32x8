#!/usr/bin/env bash
# Extract a netlist WITH parasitic capacitance from the OpenRAM GDS.
# Output: ~/sram_work/pex/sram_pex.spice (then run ~/sram_work/sim/prep_netlist.sh)
# Magic scratch files (.mag/.ext) stay in work/.
set -euo pipefail
MACRO="$(cd "$(dirname "$0")/.." && pwd)/macro"   # committed copy of the OpenRAM output
cd "$(dirname "$0")"; mkdir -p work; cd work
cp "$MACRO/.magicrc" .
ln -sf "$MACRO/sky130_sram_0kbytes_1rw_8x16_8.gds" .
~/sram_work/nixrun ../run_pex.sh > ../run_pex.log 2>&1
mv sram_pex.spice ..
echo "sram_pex.spice: $(grep -c "^C" ../sram_pex.spice) caps, $(grep -c sky130_fd_pr ../sram_pex.spice) transistors (log: run_pex.log)"
