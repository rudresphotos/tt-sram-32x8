#!/usr/bin/env bash
# D2: Liberty (.lib) model of the SRAM macro from ngspice simulation (not OpenRAM's analytical estimate), one
# PVT corner per call, with OpenRAM's own characterizer (sram_char.py: it calls the characterizer directly, so
# the skip-characterization change in compiler/sram.py is not on this path).
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

step "1/4 OpenRAM environment"
SETUP_ONLY=1 "$ROOT/flow/build_macro.sh" >/dev/null || fail "OpenRAM setup (run SETUP_ONLY=1 flow/build_macro.sh to see why)"
export OPENRAM_HOME="$OR/compiler" OPENRAM_TECH="$OR/technology" PDK_ROOT="$OR" CHAR_CORNER="$CORNER"

step "2/4 ngspice characterization, corner $CORNER, netlist $SP"
cp "$ROOT/flow/openram/sky130_sram_common.py" "$ROOT/flow/openram/$NAME.py" "$ROOT/flow/openram/char_$NAME.py" "$OR/macros/sram_configs/"
rm -rf "$OR/macros/char/$CORNER"
mkdir -p "$OR/macros/char"
start=$(date +%s)
(cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command \
   bash -c "cd macros && '$OR/.venv/bin/python3' -u ../sram_char.py -v sram_configs/char_$NAME.py '$SP'") \
   || fail "sram_char.py (see output above)"
echo "characterization took $(( $(date +%s) - start )) s"

step "3/4 collect the .lib"
LIB=$(ls "$OR/macros/char/$CORNER"/*.lib 2>/dev/null | head -1)
[ -s "$LIB" ] || fail "no .lib written in $OR/macros/char/$CORNER"
mkdir -p "$ROOT/build/macro/lib" "$ROOT/build/char/$CORNER"
cp -a "$OR/macros/char/$CORNER/." "$ROOT/build/char/$CORNER/"
cp "$LIB" "$ROOT/build/macro/lib/"
echo "$(basename "$LIB")"

step "4/4 sanity check"
"$ROOT/.venv-flow/bin/python3" "$ROOT/flow/lib_sanity.py" "$ROOT/build/macro/lib/$(basename "$LIB")" || fail "lib sanity check"
