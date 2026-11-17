#!/usr/bin/env bash
# Debug helper: run the TT characterization for at most CHAR_TRIP_S seconds and print the first measurements,
# to check quickly that the probes (bit storage, s_en, dout) resolve before committing to a multi-hour run.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INSTALL=0 "$ROOT/flow/build_macro.sh" trip > /tmp/trip_macro.log 2>&1 || { tail -30 /tmp/trip_macro.log; exit 1; }
timeout "${CHAR_TRIP_S:-720}" "$ROOT/flow/characterize.sh" TT "$ROOT/build/macro_runs/trip/raw/tt_sram_8x32_wpr1.sp" > /tmp/trip_char.log 2>&1
echo "exit: $?"
grep -E "Trying feasible|Spice:|check_bit_measures|s_en delay|delay_lh|delay_hl|Found feasible|feasible_period passed|ERROR|Traceback" /tmp/trip_char.log | cut -c1-200 | head -60
