#!/usr/bin/env bash
# Regenerate the SRAM macro the tile uses, from the OpenRAM config, and install it into build/macro/:
#   OpenRAM v1.2.50 (pinned commit + Rudr's two local changes, flow/openram/*.diff)  -> raw GDS/LEF/V/SP
#   build/tools/fix_implants.py      (implant gap fill for the KLayout FEOL rules)  -> GDS used in the tile
#   build/tools/open_obs_columns.py  (frees the two met4 power-stripe columns in the LEF OBS, see pdn/pdn_cfg.tcl)
# Stops with a clear message at the first step that fails. Linux x86_64 only (OpenRAM's Nix flake).
#
# usage: flow/build_macro.sh [RUN_TAG]       (default tag: repro)  outputs also kept in build/macro_runs/RUN_TAG/
# env:   OPENRAM_DIR   OpenRAM checkout + its PDK (default ~/OpenRAM, as in the team's setup)
#        INSTALL=0     build and check only, do not overwrite build/macro/
#        SETUP_ONLY=1  stop after step 3 (OpenRAM + venvs + PDK ready; used by flow/characterize.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-repro}"
OR="${OPENRAM_DIR:-$HOME/OpenRAM}"
INSTALL="${INSTALL:-1}"
OPENRAM_COMMIT=2f7b3866418ac1ce17ad959207a1489033d8c577   # OpenRAM v1.2.50, the version the try9 macro was made with
NAME=tt_sram_8x32_wpr1
# met4 columns (macro-local um) opened in the LEF OBS for the VGND / VPWR stripes: stripe +- 0.3 um met4 spacing.
# Stripes at macro-local 15.14..16.74 and 21.51..23.11 (build/pdn/pdn_cfg.tcl).
OBS_COLS="14.84,17.04;21.21,23.41"
OUT="$ROOT/build/macro_runs/$TAG"   # not under build/runs/: LibreLane --overwrite deletes its run dir
FLOWPY="$ROOT/.venv-flow/bin/python3"

step() { echo; echo "=== [$(date -u +%H:%M:%S)] $* ==="; }
fail() { echo; echo "BUILD FAILED at step: $*" >&2; exit 1; }

command -v nix >/dev/null || fail "nix not found (install Nix with flakes enabled)"
export OPENRAM_HOME="$OR/compiler" OPENRAM_TECH="$OR/technology" PDK_ROOT="$OR"
nixdev() { (cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command "$@"); }

step "1/7 OpenRAM checkout at $OPENRAM_COMMIT + local patch"
if [ ! -d "$OR/.git" ]; then
  git init -q "$OR"
  git -C "$OR" remote add origin https://github.com/VLSIDA/OpenRAM.git
fi
if [ "$(git -C "$OR" rev-parse HEAD 2>/dev/null || true)" != "$OPENRAM_COMMIT" ]; then
  git -C "$OR" fetch -q --depth 1 origin "$OPENRAM_COMMIT" || fail "fetch OpenRAM $OPENRAM_COMMIT"
  # -f: a restored CI cache of the PDK/cell-library folders contains files that are also tracked by git
  git -C "$OR" checkout -q -f "$OPENRAM_COMMIT"
fi
# Rudr's local OpenRAM diff, split in two: the nwell.5a fix (always) and skip-characterization (only for the
# macro build, as in try9; flow/characterize.sh takes it out again).
for PATCH in "$ROOT/flow/openram/openram_nwell5a.diff" "$ROOT/flow/openram/openram_skip_characterization.diff"; do
  if git -C "$OR" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "already applied: $(basename "$PATCH")"
  else
    git -C "$OR" apply "$PATCH" || fail "apply $PATCH"
    echo "applied: $(basename "$PATCH")"
  fi
done

step "2/7 Python venvs (OpenRAM: pinned requirements; flow tools: klayout)"
if ! "$OR/.venv/bin/python3" -c "import numpy, scipy, openram" 2>/dev/null; then
  python3 -m venv "$OR/.venv"
  "$OR/.venv/bin/pip" install -q -r "$ROOT/flow/openram/requirements-venv.txt" || fail "pip install OpenRAM requirements"
  "$OR/.venv/bin/pip" install -q -e "$OR" || fail "pip install -e OpenRAM"
fi
if ! "$FLOWPY" -c "import klayout.db" 2>/dev/null; then
  python3 -m venv "$ROOT/.venv-flow"
  "$ROOT/.venv-flow/bin/pip" install -q klayout==0.30.13 || fail "pip install klayout"
fi
"$OR/.venv/bin/python3" --version

step "3/7 OpenRAM's SKY130 PDK + SRAM cell library (first time: downloads; Nix also fetches magic/netgen/ngspice)"
[ -d "$OR/sky130A" ] || nixdev make sky130-pdk || fail "make sky130-pdk"
[ -d "$OR/technology/sky130/maglef_lib" ] || nixdev make sky130-install || fail "make sky130-install"
nixdev bash -c 'for t in magic netgen ngspice klayout; do printf "%-8s %s\n" "$t" "$(readlink -f "$(command -v $t)" || echo MISSING)"; done'
# Rudr's fixed dummy cell (17 Nov 2026, build/openram_cells/README.md): one li1 rectangle ties the two floating
# gates of sky130_custom_dummy to VGND. Installed over OpenRAM's copy exactly as that README says.
for f in gds:gds_lib sp:sp_lib; do
  src="$ROOT/build/openram_cells/sky130_custom_dummy.${f%%:*}" dst="$OR/technology/sky130/${f#*:}/sky130_custom_dummy.${f%%:*}"
  [ -f "$dst" ] || fail "OpenRAM has no $dst"
  cp "$src" "$dst"
  echo "dummy cell: $(basename "$src") -> ${f#*:}/  md5 $(md5sum "$dst" 2>/dev/null | cut -c1-32 || md5 -q "$dst")"
done

if [ "${SETUP_ONLY:-0}" = 1 ]; then echo "SETUP_ONLY=1: OpenRAM environment ready in $OR"; exit 0; fi

step "4/7 OpenRAM: generate $NAME (OpenRAM runs its own Magic DRC + Netgen LVS)"
cp "$ROOT/flow/openram/sky130_sram_common.py" "$ROOT/flow/openram/$NAME.py" "$OR/macros/sram_configs/"
rm -rf "$OR/macros/macro/$NAME"
mkdir -p "$OR/macros/macro"   # OpenRAM creates only the last directory level of output_path
nixdev bash -c "cd macros && '$OR/.venv/bin/python3' -u ../sram_compiler.py -v sram_configs/$NAME.py" \
  || fail "OpenRAM (see $OR/macros/macro/$NAME/$NAME.log)"
RAW="$OR/macros/macro/$NAME"
rm -rf "$OUT" && mkdir -p "$OUT/raw" && cp -a "$RAW/." "$OUT/raw/"

step "5/7 check OpenRAM's own results"
LOG="$OUT/raw/$NAME.log"
grep -E "Using (DRC|LVS|PEX):" "$LOG" || true
grep -qP "DRC Errors $NAME\t0$" "$LOG" || fail "OpenRAM DRC is not 0: $(grep 'DRC Errors' "$LOG" || echo 'no DRC line')"
grep -qP "$NAME\tLVS matches" "$LOG" || fail "OpenRAM LVS does not match: $(grep 'LVS' "$LOG" | tail -2)"
for f in gds lef v sp; do [ -s "$OUT/raw/$NAME.$f" ] || fail "missing OpenRAM output $NAME.$f"; done
echo "DRC 0, LVS matches; $(grep -m1 SIZE "$OUT/raw/$NAME.lef" | sed 's/^ *//')"

step "6/7 fix_implants.py on the GDS, open_obs_columns.py on the LEF"
"$FLOWPY" "$ROOT/flow/klayout_run.py" "$ROOT/build/tools/fix_implants.py" \
  gds_in="$OUT/raw/$NAME.gds" gds_out="$OUT/$NAME.gds" | tee "$OUT/fix_implants.txt" || fail "fix_implants.py"
"$FLOWPY" "$ROOT/flow/klayout_run.py" "$ROOT/build/tools/open_obs_columns.py" \
  lef_in="$OUT/raw/$NAME.lef" lef_out="$OUT/$NAME.lef" cols="$OBS_COLS" || fail "open_obs_columns.py"
cp "$OUT/raw/$NAME.lef" "$OUT/$NAME.orig.lef"
cp "$OUT/raw/$NAME.v" "$OUT/raw/$NAME.log" "$OUT/raw/$NAME.py" "$OUT/"

step "7/7 install into build/macro/"
if [ "$INSTALL" = 1 ]; then
  for f in gds lef orig.lef v log py; do cp "$OUT/$NAME.$f" "$ROOT/build/macro/$NAME.$f"; done
  echo "installed: $(cd "$ROOT/build/macro" && ls)"
else
  echo "INSTALL=0: left build/macro/ unchanged"
fi
echo
echo "MACRO OK: $OUT"
