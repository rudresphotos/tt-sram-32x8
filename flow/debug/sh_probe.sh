#!/usr/bin/env bash
# Debug helper: replay OpenRAM's failing DFF setup/hold deck (flow/debug/sh_deck) with small variations.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OR="${OPENRAM_DIR:-$HOME/OpenRAM}"
SETUP_ONLY=1 "$ROOT/flow/build_macro.sh" >/dev/null || { echo "setup failed"; exit 1; }
export OPENRAM_HOME="$OR/compiler" OPENRAM_TECH="$OR/technology" PDK_ROOT="$OR"
echo "== installed DFF netlist"; sed -n '1,200p' "$OR/technology/sky130/sp_lib/sky130_fd_bd_sram__openram_dff.sp" | grep -v "^\*" | head -30
W=$(mktemp -d); cp "$ROOT"/flow/debug/sh_deck/* "$W/"
sed -i "s#/tmp/openram_[a-z_0-9]*_temp/sh_meas.sp#$W/sh_meas.sp#" "$W/sh_stim.sp"
printf "set num_threads=1\nset ngbehavior=hsa\nset ng_nomodcheck\n" > "$W/.spiceinit"
v() { name=$1; shift; cp "$W/sh_stim.sp" "$W/$name.sp"; for e in "$@"; do sed -i "$e" "$W/$name.sp"; done
  out=$(cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command bash -c "cd '$W' && ngspice -b $name.sp" 2>&1)
  echo "== $name: $(echo "$out" | grep -i -m3 'clk2q_delay\|too small\|error\|aborted' | tr '\n' ' ')"; }
v asis
v no_uic 's/ UIC$//'
v stop41 's/^\.TRAN 10p 40n 0n 10p UIC/.TRAN 10p 41n 0n 10p UIC/'
v trap 's/method=gear/method=trap/'
v tmax100p 's/^\.TRAN 10p 40n 0n 10p UIC/.TRAN 10p 40n 0n 100p UIC/'
v noplot '/^\.plot/d'
v noplot_stop41 '/^\.plot/d' 's/^\.TRAN 10p 40n 0n 10p UIC/.TRAN 10p 41n 0n 10p UIC/'
