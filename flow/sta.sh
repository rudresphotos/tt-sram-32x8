#!/usr/bin/env bash
# D3: multi-corner sign-off STA of the finished tile WITH the SRAM macro's Liberty timing.
# It re-runs only LibreLane's own sign-off STA step (OpenROAD.STAPostPNR: OpenSTA, 9 corners, extracted SPEF)
# on an existing tile run, so the layout is exactly the one built (nothing is re-placed or re-routed).
# Differences from the try9 STA: the macro gets its .lib per corner, and STA_MACRO_PRIORITIZE_NL=false
# (try9 read the macro's behavioural Verilog, so OpenSTA saw a black box with no timing arcs).
# The I/O constraints are LibreLane's default SDC (scripts/base.sdc) with the TT template values; see
# docs/timing_signoff.md.
#
# usage: flow/sta.sh [RUN_TAG]     needs build/runs/RUN_TAG (flow/build_tile.sh) and .lib files in LIB_DIR
# env:   OUT_NAME   output folder name under build/sta/ (default RUN_TAG)
#        LIB_DIR    (default build/macro/lib) with tt_sram_8x32_wpr1_{TT_1p8V_25C,SS_1p6V_100C,FF_1p95V_-40C}.lib
#        CIEL_ROOT, LIBRELANE as in flow/build_tile.sh
# output: build/sta/RUN_TAG/ (LibreLane STA reports + sta_summary.md)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-repro}"
LIB_DIR="$(cd "${LIB_DIR:-$ROOT/build/macro/lib}" && pwd)"
CIEL_ROOT="${CIEL_ROOT:-$HOME/.ciel}"
LIBRELANE="${LIBRELANE:-nix run github:librelane/librelane/3.0.14 --}"
RUN="$ROOT/build/runs/$TAG"
OUT="$ROOT/build/sta/${OUT_NAME:-$TAG}"
FLOWPY="$ROOT/.venv-flow/bin/python3"
step() { echo; echo "=== [$(date -u +%H:%M:%S)] $* ==="; }
fail() { echo; echo "STA FAILED at step: $*" >&2; exit 1; }

[ -s "$RUN/final/metrics.json" ] || fail "no finished tile run in $RUN (run flow/build_tile.sh $TAG first)"
[ -x "$FLOWPY" ] || python3 -m venv "$ROOT/.venv-flow" || fail "python venv"
"$FLOWPY" -c "import yaml" 2>/dev/null || "$ROOT/.venv-flow/bin/pip" install -q pyyaml || fail "pip install pyyaml"

step "1/3 STA config: build/config.yaml + macro .lib per corner (from $LIB_DIR)"
"$FLOWPY" - "$ROOT/build/config.yaml" "$ROOT/build/config_sta.yaml" "$LIB_DIR" <<'EOF' || fail "write config_sta.yaml"
import os, sys, yaml
src, dst, lib_dir = sys.argv[1:]
cfg = yaml.safe_load(open(src))
name = "tt_sram_8x32_wpr1"
files = {  # LibreLane corner pattern -> OpenRAM corner file name
    "*_tt_025C_1v80": f"{name}_TT_1p8V_25C.lib",
    "*_ss_100C_1v60": f"{name}_SS_1p6V_100C.lib",
    "*_ff_n40C_1v95": f"{name}_FF_1p95V_-40C.lib",
}
lib = {}
for corner, f in files.items():
    p = os.path.join(lib_dir, f)
    if os.path.isfile(p):
        lib[corner] = [p]
        print(f"  {corner}: {p}")
    else:
        print(f"  {corner}: MISSING {p}")
if "*_tt_025C_1v80" not in lib:
    sys.exit("the TT .lib is required")
cfg["MACROS"][name]["lib"] = lib
cfg["STA_MACRO_PRIORITIZE_NL"] = False
# only the corners that have a macro .lib (a corner without one would time the macro as a black box)
cfg["STA_CORNERS"] = [f"{m}_{c[2:]}" for c in lib for m in ("nom", "min", "max")]
print("  STA_CORNERS:", cfg["STA_CORNERS"])
yaml.safe_dump(cfg, open(dst, "w"), sort_keys=False)
EOF

step "2/3 LibreLane OpenROAD.STAPostPNR on run $TAG"
cd "$ROOT/build"
# shellcheck disable=SC2086
$LIBRELANE --pdk-root "$CIEL_ROOT" --run-tag "$TAG" --only OpenROAD.STAPostPNR config_sta.yaml || fail "LibreLane STA (see $RUN)"
STEP_DIR="$(ls -d "$RUN"/*-openroad-stapostpnr* | sort -t- -k1,1n | tail -1)"
echo "reports: $STEP_DIR"

step "3/3 collect reports + summary"
rm -rf "$OUT" && mkdir -p "$OUT"
cp -a "$STEP_DIR/." "$OUT/"
cp "$ROOT/build/config_sta.yaml" "$OUT/"
"$FLOWPY" "$ROOT/flow/sta_summary.py" "$OUT" | tee "$OUT/sta_summary.md" || fail "sta_summary.py"
