#!/usr/bin/env bash
# One-shot: generate testbench, simulate, check.
#   ./run.sh <test> [sramtb.py gen options...]      e.g.  ./run.sh march --netlist pex
set -euo pipefail
cd "$(dirname "$0")"
test="$1"; shift
out=$(python3 sramtb.py gen "$test" "$@"); echo "$out"
run=$(echo "$out" | sed -E 's|^runs/(.+)\.sp: .*|\1|')
start=$(date +%s)
~/sram_work/nixrun ngspice -b "runs/$run.sp" -o "runs/$run.log" > /dev/null 2>&1 || true
echo "simulated in $(( $(date +%s) - start )) s"
grep -iE "^Error|fatal|could not find" "runs/$run.log" | head -5 || true
python3 sramtb.py check "$run" | tail -n 20
