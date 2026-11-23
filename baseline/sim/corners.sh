#!/usr/bin/env bash
# Run one test on the PEX netlist across process/temperature corners, 3 sims in parallel.
#   ./corners.sh <test> [extra sramtb.py gen options]      e.g.  ./corners.sh march
#   CORNERS="ff:-40 ss:100" ./corners.sh debug --glitch      (override the corner list)
# Prints one summary line per corner; full results in runs/<test>_pex[_<corner><temp>C]*.log
set -euo pipefail
cd "$(dirname "$0")"
CORNERS="${CORNERS:-tt:25 ff:-40 ff:100 ss:-40 ss:100 fs:25 sf:25}"
export TEST="$1"; shift

one() {   # $1 = corner:temp, rest = extra options
  local c=${1%%:*} t=${1##*:}; shift
  ./run.sh "$TEST" --netlist pex --corner "$c" --temp "$t" "$@" | grep -E "^\[|simulated in" | tr "\n" " "
  echo
}
export -f one
printf "%s\n" $CORNERS | xargs -P 3 -I{} bash -c 'one "$@"' _ {} "$@"
