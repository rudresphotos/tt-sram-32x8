#!/usr/bin/env bash
# Regenerate the SRAM macro with OpenRAM from openram/sky130_sram_1rw_8x16.py and copy the result into macro/.
# Uses the Python venv ~/OpenRAM/.venv (numpy, scipy, ...) made by setup.sh, inside the Nix shell (magic, netgen).
# OpenRAM runs its own DRC (Magic) and LVS (Netgen) at the end; check the summary it prints.
# Afterwards re-verify:  pex/extract.sh && sim/prep_netlist.sh && sim/corners.sh march
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG=sky130_sram_1rw_8x16.py
OUT=sky130_sram_0kbytes_1rw_8x16_8          # name OpenRAM derives from the config

cp "$REPO/openram/$CONFIG" ~/OpenRAM/macros/sram_configs/
cd ~/OpenRAM/macros
"$REPO/nixrun" ~/OpenRAM/.venv/bin/python3 -u ../sram_compiler.py -v "sram_configs/$CONFIG"
grep -E "DRC Errors|LVS" "macro/$OUT/$OUT.log" || true
rm -rf "$REPO/macro" && cp -a "macro/$OUT" "$REPO/macro"
echo "copied ~/OpenRAM/macros/macro/$OUT -> $REPO/macro"
