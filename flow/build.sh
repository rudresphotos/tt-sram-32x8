#!/usr/bin/env bash
# One command for the whole tile: OpenRAM macro -> fix_implants -> build/macro -> LibreLane -> gate-level test
# -> tt_submission/ -> TT precheck. Stops at the first step that fails.
#
# usage: flow/build.sh [RUN_TAG]        (default tag: repro)      same as: make tile
# env:   SKIP_MACRO=1      use the macro already in build/macro/ (skip OpenRAM)
#        SKIP_PRECHECK=1   skip the local TT precheck (CI runs TT's own precheck action instead)
#        CHECK_TRY9=1      also compare the result with the signed-off try9 run (flow/compare_try9.py)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-repro}"

banner() { echo; echo "##### $* #####"; }

if [ "${SKIP_MACRO:-0}" != 1 ]; then
  banner "MACRO"
  "$ROOT/flow/build_macro.sh" "$TAG"
fi

banner "TILE"
"$ROOT/flow/build_tile.sh" "$TAG"

if [ "${SKIP_PRECHECK:-0}" != 1 ]; then
  banner "TT PRECHECK"
  "$ROOT/flow/precheck.sh" "$ROOT/tt_submission/tt_um_rudresphotos_sram.gds"
fi

if [ "${CHECK_TRY9:-0}" = 1 ]; then
  banner "COMPARE WITH TRY9"
  MACRO_ARG=()
  [ "${SKIP_MACRO:-0}" = 1 ] || MACRO_ARG=("$ROOT/build/macro_runs/$TAG")
  "$ROOT/.venv-flow/bin/python3" "$ROOT/flow/compare_try9.py" "$ROOT/build/runs/$TAG" "${MACRO_ARG[@]}"
fi

echo
echo "ALL STEPS OK (run tag $TAG)"
