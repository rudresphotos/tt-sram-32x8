#!/usr/bin/env bash
# Local Tiny Tapeout precheck, the same steps as TinyTapeout/tt-gds-action/precheck@ttsky26e, with the
# tt-support-tools commit and TT PDK version used for try9.
# usage: flow/precheck.sh <tile.gds>       reports land in build/precheck/tt/precheck/reports/
# env:   PRECHECK_DIR (default build/precheck)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GDS="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
DIR="${PRECHECK_DIR:-$ROOT/build/precheck}"
TOOLS_REF=9d13ff3e3e6202090740110438c6a10c1d62ca0f      # tt-support-tools, as in try9
TT_PDK=0536d02d875c8f67dd7cca3902ac457e62f20005         # sky130A version TT precheck uses for TTSKY26e
fail() { echo; echo "PRECHECK FAILED at step: $*" >&2; exit 1; }

mkdir -p "$DIR"
if [ ! -d "$DIR/tt/.git" ]; then
  git init -q "$DIR/tt" && git -C "$DIR/tt" remote add origin https://github.com/TinyTapeout/tt-support-tools.git
fi
if [ "$(git -C "$DIR/tt" rev-parse HEAD 2>/dev/null || true)" != "$TOOLS_REF" ]; then
  git -C "$DIR/tt" fetch -q --depth 1 origin "$TOOLS_REF" && git -C "$DIR/tt" checkout -q "$TOOLS_REF" || fail "fetch tt-support-tools"
fi
if [ ! -x "$DIR/venv/bin/python" ]; then
  python3 -m venv "$DIR/venv"
  "$DIR/venv/bin/pip" install -q -r "$DIR/tt/precheck/requirements.txt" ciel==3.2.0 || fail "pip install precheck requirements"
fi
export PDK=sky130A PDK_ROOT="$DIR/pdk"
[ -d "$PDK_ROOT/ciel/sky130/versions/$TT_PDK" ] || "$DIR/venv/bin/ciel" enable --pdk-root "$PDK_ROOT" --pdk sky130 "$TT_PDK" \
  || fail "ciel enable sky130 $TT_PDK"
cd "$DIR/tt/precheck"
PATH="$DIR/venv/bin:$PATH" nix-shell --run "python precheck.py --gds '$GDS' --tech sky130A" || fail "precheck (see $DIR/tt/precheck/reports)"
cat reports/results.md
