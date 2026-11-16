#!/usr/bin/env bash
# Debug helper: why does ngspice-45 say "could not find a valid modelname" for OpenRAM's sky130 netlist?
# Prints how the PDK model files set scale / bin limits and runs one nfet with the settings OpenRAM uses.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OR="${OPENRAM_DIR:-$HOME/OpenRAM}"
SETUP_ONLY=1 "$ROOT/flow/build_macro.sh" >/dev/null || { echo "setup failed"; exit 1; }
M="$OR/sky130A/libs.tech/ngspice"
echo "== PDK: $(readlink -f "$OR/sky130A")"
echo "== scale / option lines in the ngspice model tree"
grep -rn -i "option.*scale\|^\s*\.option" "$M"/sky130.lib.spice "$M"/corners/tt.spice "$M"/all.spice 2>/dev/null | head -20
grep -rln -i "scale" "$M" 2>/dev/null | head -10
F=$(grep -rl "sky130_fd_pr__nfet_01v8__model.0 " "$M" 2>/dev/null | head -1); echo "== bin file: $F"
[ -n "$F" ] && grep -n -A12 "sky130_fd_pr__nfet_01v8__model.0 " "$F" | grep -i "lmin\|lmax\|wmin\|wmax" | head
grep -n -i "subckt sky130_fd_pr__nfet_01v8 \|\.param" "$(grep -rl 'subckt sky130_fd_pr__nfet_01v8 ' "$M" | head -1)" | head -5
W=$(mktemp -d)
deck() {  # $1 = name, $2 = W/L spec, $3 = extra option line
cat > "$W/$1.sp" <<DECK
* probe $1
.lib "$M/sky130.lib.spice" tt
$3
Vd d 0 1.8
Vg g 0 1.8
X1 d g 0 0 sky130_fd_pr__nfet_01v8 $2
.op
.print op i(Vd)
.end
DECK
}
deck unitless "W=0.74 L=0.15" ""
deck microns  "W=0.74u L=0.15u" ""
deck unitless_scale "W=0.74 L=0.15" ".option scale=1e-6"
for beh in hsa hs kia; do
  for d in unitless microns unitless_scale; do
    printf "set ngbehavior=%s\nset ng_nomodcheck\n" "$beh" > "$W/.spiceinit"
    out=$(cd "$W" && (cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command bash -c "cd '$W' && ngspice -b $d.sp") 2>&1)
    res=$(echo "$out" | grep -i -m1 "valid modelname\|i(vd)\|vd#branch\|error" )
    echo "ngbehavior=$beh deck=$d -> $res"
  done
done
(cd "$OR" && nix --extra-experimental-features 'nix-command flakes' develop --quiet --command ngspice -v) 2>&1 | head -3
