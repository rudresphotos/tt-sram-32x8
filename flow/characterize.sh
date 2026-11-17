#!/usr/bin/env bash
# D2: Liberty (.lib) model of the SRAM macro from ngspice simulation (not OpenRAM's analytical estimate), one
# PVT corner per call, with OpenRAM's stand-alone characterizer sram_char.py on the macro's netlist.
# Why sram_char.py and not the generator: in OpenRAM's generator flow (compiler/sram.py) characterization stops
# with "Could not find bl net in timing paths." for this sky130 config (also in Rudr's try9 macro log, which is
# why the skip-characterization change exists). sram_char.py calls the same delay/setup-hold characterizer
# but names the probe nets from patterns instead of that timing-graph search.
# One characterizer-only patch (flow/openram/openram_memchar_storage_names.diff): the bitcell storage nets are
# read from the config (sky130_custom_cell calls them Q / Qbar; OpenRAM hard-codes Q / Q_bar). No circuit change.
# The netlist copy that is simulated has 6 transistor sizes rewritten from W=0.74u to W=0.74 (same size, the unit
# convention of the rest of the netlist under the PDK's .option scale=1.0u), see flow/normalize_units.py.
# Second characterizer-only patch (flow/openram/openram_setup_hold_tmax.diff): the DFF setup/hold decks use a
# 100 ps max time step; with 10 ps ngspice-45 aborts them at the stop time ("Timestep too small").
# Third (flow/openram/openram_memchar_area.diff): the stand-alone characterizer has no layout object, so the
# macro width/height for the .lib area come from the macro LEF (CHAR_MACRO_W/H -> memchar_width/height).
#
# usage: flow/characterize.sh CORNER [SPICE_NETLIST]
#   CORNER         TT (1.80 V 25 C) | SS (1.60 V 100 C) | FF (1.95 V -40 C)   = LibreLane's three corners
#   SPICE_NETLIST  default build/macro_runs/repro/raw/tt_sram_8x32_wpr1.sp (OpenRAM's LVS-clean netlist of the macro)
# output: build/macro/lib/tt_sram_8x32_wpr1_<corner>.lib  (+ log in build/char/<CORNER>/)
# env:   OPENRAM_DIR (default ~/OpenRAM), CHAR_THREADS (ngspice threads, default 4)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORNER="${1:?usage: flow/characterize.sh TT|SS|FF [netlist.sp]}"
SP="$(cd "$(dirname "${2:-$ROOT/build/macro_runs/repro/raw/tt_sram_8x32_wpr1.sp}")" && pwd)/$(basename "${2:-tt_sram_8x32_wpr1.sp}")"
OR="${OPENRAM_DIR:-$HOME/OpenRAM}"
NAME=tt_sram_8x32_wpr1
case "$CORNER" in TT|SS|FF) ;; *) echo "CORNER must be TT, SS or FF" >&2; exit 2 ;; esac
step() { echo; echo "=== [$(date -u +%H:%M:%S)] $* ==="; }
fail() { echo; echo "CHARACTERIZATION FAILED at step: $*" >&2; exit 1; }
[ -s "$SP" ] || fail "netlist $SP not found (run flow/build_macro.sh first)"

step "1/5 OpenRAM environment + characterizer patch"
SETUP_ONLY=1 "$ROOT/flow/build_macro.sh" >/dev/null || fail "OpenRAM setup (run SETUP_ONLY=1 flow/build_macro.sh to see why)"
export OPENRAM_HOME="$OR/compiler" OPENRAM_TECH="$OR/technology" PDK_ROOT="$OR" CHAR_CORNER="$CORNER"
for CPATCH in "$ROOT/flow/openram/openram_memchar_storage_names.diff" "$ROOT/flow/openram/openram_setup_hold_tmax.diff" \
              "$ROOT/flow/openram/openram_memchar_area.diff"; do
  git -C "$OR" apply --reverse --check "$CPATCH" 2>/dev/null || git -C "$OR" apply "$CPATCH" || fail "apply $CPATCH"
done
git -C "$OR" diff --stat

step "2/5 netlist units for ngspice (flow/normalize_units.py: 6 transistors of sky130_custom_nand3_dec)"
mkdir -p "$ROOT/build/char/$CORNER"
SIM_SP="$ROOT/build/char/$CORNER/${NAME}_sim.sp"
"$ROOT/.venv-flow/bin/python3" "$ROOT/flow/normalize_units.py" "$SP" "$SIM_SP" 6 || fail "netlist unit normalization"
SP="$SIM_SP"

# macro width/height for the .lib area, from the LEF next to the netlist (OpenRAM's own LEF of this macro)
LEF="$(dirname "${2:-$ROOT/build/macro_runs/repro/raw/x}")/$NAME.lef"
read -r CHAR_MACRO_W CHAR_MACRO_H < <(awk '/SIZE/ {print $2, $4; exit}' "$LEF") || fail "no SIZE in $LEF"
export CHAR_MACRO_W CHAR_MACRO_H
echo "macro size from $LEF: $CHAR_MACRO_W x $CHAR_MACRO_H um"

step "3/5 ngspice characterization, corner $CORNER, netlist $SP"
cp "$ROOT/flow/openram/sky130_sram_common.py" "$ROOT/flow/openram/$NAME.py" "$ROOT/flow/openram/char_$NAME.py" "$OR/macros/sram_configs/"
rm -rf "$OR/macros/char/$CORNER"
mkdir -p "$OR/macros/char"
start=$(date +%s)
(cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command \
   bash -c "cd macros && '$OR/.venv/bin/python3' -u ../sram_char.py -v -v sram_configs/char_$NAME.py '$SP'") \
   || fail "sram_char.py (see output above)"
echo "characterization took $(( $(date +%s) - start )) s"

step "4/5 collect the .lib"
LIB=$(ls "$OR/macros/char/$CORNER"/*.lib 2>/dev/null | head -1)
[ -s "$LIB" ] || fail "no .lib written in $OR/macros/char/$CORNER"
mkdir -p "$ROOT/build/macro/lib" "$ROOT/build/char/$CORNER"
cp -a "$OR/macros/char/$CORNER/." "$ROOT/build/char/$CORNER/"
cp "$SIM_SP" "$ROOT/build/char/$CORNER/" 2>/dev/null || true
cp "$LIB" "$ROOT/build/macro/lib/"
echo "$(basename "$LIB")"

step "5/5 sanity check"
"$ROOT/.venv-flow/bin/python3" "$ROOT/flow/lib_sanity.py" "$ROOT/build/macro/lib/$(basename "$LIB")" || fail "lib sanity check"
