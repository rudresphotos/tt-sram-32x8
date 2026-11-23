#!/bin/sh
export OPENRAM_TECH="/home/karthik_sram/OpenRAM/technology:/home/karthik_sram/OpenRAM/technology"
echo "$(date): Starting LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
/nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen -noconsole << EOF
lvs {sky130_sram_0kbytes_1rw_8x16_8.spice sky130_sram_0kbytes_1rw_8x16_8} {sky130_sram_0kbytes_1rw_8x16_8.lvs.sp sky130_sram_0kbytes_1rw_8x16_8} setup.tcl sky130_sram_0kbytes_1rw_8x16_8.lvs.report -full -json
quit
EOF
magic_retcode=$?
echo "$(date): Finished ($magic_retcode) LVS using Netgen /nix/store/h3crgmx1w7h86qjpr131igi7p576mp3x-netgen-1.5.318/bin/netgen"
exit $magic_retcode
