#!/bin/bash
# usage: magic_drc_gds.sh <gds> <topcell> <PDK_ROOT>   -> full Magic DRC (sky130A, drc(full)) count + rule names
gds=$1; top=$2; pdk=$3
cat > /tmp/mdrc_$$.tcl <<TCL
gds read $gds
load $top
select top cell
drc style drc(full)
drc check
drc catchup
set res [drc listall why]
set n 0
foreach {why boxes} \$res { puts "RULE: \$why  ([llength \$boxes] boxes)"; incr n [llength \$boxes] }
puts "TOTAL_BOXES: \$n"
quit -noprompt
TCL
magic -dnull -noconsole -rcfile $pdk/sky130A/libs.tech/magic/sky130A.magicrc /tmp/mdrc_$$.tcl 2>&1 | grep -E "RULE:|TOTAL_BOXES"
rm -f /tmp/mdrc_$$.tcl
