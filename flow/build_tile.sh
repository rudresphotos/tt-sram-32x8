#!/usr/bin/env bash
# Rebuild the Tiny Tapeout tile with LibreLane 3.0.14 from build/config.yaml (the try9 config), then
# run the gate-level TT-pin test and package tt_submission/ the same way TT's custom_gds action does.
# Stops with a clear message at the first step that fails.
#
# usage: flow/build_tile.sh [RUN_TAG]          (default tag: repro)
# env:   CIEL_ROOT   where ciel keeps PDKs     (default ~/.ciel, as in try9)
#        LIBRELANE   command that runs LibreLane (default: nix run of the pinned 3.0.14 release)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-repro}"
CIEL_ROOT="${CIEL_ROOT:-$HOME/.ciel}"
LIBRELANE="${LIBRELANE:-nix run github:librelane/librelane/3.0.14 --}"
TOP=tt_um_rudresphotos_sram
EXPECTED_PDK=8afc8346a57fe1ab7934ba5a6056ea8b43078e71   # sky130 version pinned by LibreLane 3.0.14 (pdk_hashes.yaml) = try9
RUN="$ROOT/build/runs/$TAG"

step() { echo; echo "=== [$(date -u +%H:%M:%S)] $* ==="; }
fail() { echo; echo "BUILD FAILED at step: $*" >&2; exit 1; }

step "1/4 LibreLane 3.0.14 (run tag: $TAG)"
cd "$ROOT/build"
# shellcheck disable=SC2086  # LIBRELANE is a command line on purpose
$LIBRELANE --pdk-root "$CIEL_ROOT" --run-tag "$TAG" --overwrite config.yaml || fail "LibreLane (see $RUN/flow.log)"

step "2/4 check the run used the try9 PDK and produced the outputs"
PDK_ROOT_USED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["PDK_ROOT"])' "$RUN/resolved.json")"
echo "PDK_ROOT = $PDK_ROOT_USED"
case "$PDK_ROOT_USED" in *"$EXPECTED_PDK"*) ;; *) fail "PDK version is not $EXPECTED_PDK" ;; esac
for f in "final/gds/$TOP.gds" "final/lef/$TOP.lef" "final/pnl/$TOP.pnl.v" "final/metrics.json"; do
  [ -s "$RUN/$f" ] || fail "missing output $RUN/$f"
done
echo "outputs present"

step "3/4 gate-level TT-pin test (iverilog, test/tb_gl.v)"
# run via bash: test/run_gl.sh is not executable in git
GL_OUT="$(PDK_ROOT="$PDK_ROOT_USED" NETLIST="$RUN/final/pnl/$TOP.pnl.v" bash "$ROOT/test/run_gl.sh")" || fail "gate-level sim did not run"
echo "$GL_OUT"
echo "$GL_OUT" > "$RUN/gl_test.txt"
echo "$GL_OUT" | grep -q "0 errors -> PASS" || fail "gate-level test did not PASS"

step "4/4 package tt_submission/ (same file names as TT's custom_gds action)"
mkdir -p "$ROOT/tt_submission"
cp "$RUN/final/gds/$TOP.gds" "$ROOT/tt_submission/$TOP.gds"
cp "$RUN/final/lef/$TOP.lef" "$ROOT/tt_submission/$TOP.lef"
cp "$ROOT/verilog/$TOP.v" "$ROOT/tt_submission/$TOP.v"
echo '{"PDK": "sky130A"}' > "$ROOT/tt_submission/pdk.json"
ls -la "$ROOT/tt_submission"

echo
echo "BUILD OK: run $RUN"
