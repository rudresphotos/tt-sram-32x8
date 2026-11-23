#!/usr/bin/env bash
# Build ngspice-ready netlists from OpenRAM's output. Never edits OpenRAM's files.
#
# Why a fix is needed: the SKY130 ngspice models set ".option scale=1e-6", so W/L must be
# unitless numbers in um. Anything written with a "u" suffix becomes 1e-12 m and ngspice
# fails with "could not find a valid modelname".
#   sch: only sky130_custom_nand3_dec has W=0.74u L=0.15u            -> strip the "u"
#   pex: Magic writes w=3u l=0.15u pd/ps=..u (um) and ad/as=..p (um^2) -> strip "u"/"p"
set -euo pipefail
MACRO="$(cd "$(dirname "$0")/.." && pwd)/macro"   # committed copy of the OpenRAM output
cd "$(dirname "$0")"
mkdir -p netlist runs

sed -E 's/([WL]=[0-9.]+)u\b/\1/g' "$MACRO/sky130_sram_0kbytes_1rw_8x16_8.sp" > netlist/sram_tb.sp
echo "netlist/sram_tb.sp     <- schematic ($(diff "$MACRO/sky130_sram_0kbytes_1rw_8x16_8.sp" netlist/sram_tb.sp | grep -c '^>') lines unit-fixed)"

PEX=~/sram_work/pex/sram_pex.spice
if [ -f "$PEX" ]; then
  sed -E -e 's/\b(w|l|pd|ps)=([0-9.eE+-]+)u\b/\1=\2/g' -e 's/\b(ad|as)=([0-9.eE+-]+)p\b/\1=\2/g' "$PEX" > netlist/sram_pex.spice
  echo "netlist/sram_pex.spice <- layout extraction ($(grep -c '^C' netlist/sram_pex.spice) parasitic caps)"
  # probe copy: buffer each wordline onto a clean node name (xsram.wlp<r>) for glitch measurements
  WLPATH=sky130_sram_0kbytes_1rw_8x16_8_bank_0/sky130_sram_0kbytes_1rw_8x16_8_port_address_0
  { sed '/^\.ends/d' netlist/sram_pex.spice     # flat netlist: the only .ends is the last line
    for r in $(seq 0 16); do echo "Ewlp$r wlp$r 0 $WLPATH/wl_$r 0 1"; done
    B=sky130_sram_0kbytes_1rw_8x16_8_bank_0
    echo "Ewlenp wlenp 0 $B/wl_en0 0 1"
    echo "Ewenp wenp 0 $B/w_en0 0 1"
    echo "Esenp senp 0 $B/s_en0 0 1"
    echo "Epenp penp 0 $B/p_en_bar0 0 1"
    echo "Erblp rblp 0 $B/rbl_bl_0_0 0 1"
    echo "Eblp blp 0 $B/sky130_sram_0kbytes_1rw_8x16_8_port_data_0/bl_0 0 1"
    echo "Ebrp brp 0 $B/sky130_sram_0kbytes_1rw_8x16_8_port_data_0/br_0 0 1"
    echo ".ends"; } > netlist/sram_pex_probe.spice
  # every probed net must really exist in the extracted netlist (else the probe would sit on a floating node)
  for n in $(grep -o "^E[a-z0-9]* [a-z0-9]* 0 [^ ]*" netlist/sram_pex_probe.spice | awk '{print $4}'); do
    grep -q " $n " netlist/sram_pex.spice || { echo "ERROR: probe net $n not found in PEX netlist"; exit 1; }
  done
  echo "netlist/sram_pex_probe.spice <- same + wordline probes"
else
  echo "no PEX netlist yet (run ~/sram_work/pex/run_pex.sh first)"
fi
