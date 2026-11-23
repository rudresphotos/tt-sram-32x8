#!/bin/sh
# Copy of OpenRAM run_ext.sh with parasitic capacitance + coupling extraction, flat output -> sram_pex.spice
# OPENRAM_TECH and PATH (magic) come from ~/sram_work/nixrun
echo "$(date): Starting GDS to MAG using magic"

magic -dnull -noconsole << EOF
drc off
set VDD vdd
set GND gnd
set SUB gnd
gds warning default
gds flatglob *_?mos_m*
gds flatglob sky130_fd_bd_sram__sram_sp_cell_fom_serifs
gds flatglob sky130_fd_bd_sram__sram_sp_cell
gds flatglob sky130_fd_bd_sram__openram_sp_cell_opt1_replica_cell
gds flatglob sky130_fd_bd_sram__openram_sp_cell_opt1a_replica_cell
gds flatglob sky130_fd_bd_sram__sram_sp_cell_opt1_ce
gds flatglob sky130_fd_bd_sram__openram_sp_cell_opt1_replica_ce
gds flatglob sky130_fd_bd_sram__openram_sp_cell_opt1a_replica_ce
gds flatglob sky130_fd_bd_sram__sram_sp_wlstrap_ce
gds flatglob sky130_fd_bd_sram__sram_sp_wlstrap_p_ce
gds flatten true
gds ordering true
gds read sky130_sram_0kbytes_1rw_8x16_8.gds
puts "Finished reading gds sky130_sram_0kbytes_1rw_8x16_8.gds"
load sky130_sram_0kbytes_1rw_8x16_8
puts "Finished loading cell sky130_sram_0kbytes_1rw_8x16_8"
cellname delete \(UNNAMED\)
writeall force
port makeall
extract style ngspice(si)
extract do capacitance
extract do coupling
extract no resistance
extract unique all
extract all
select top cell
feedback why
puts "Finished extract"
ext2spice hierarchy off
ext2spice format ngspice
ext2spice cthresh 0.01
ext2spice rthresh infinite
ext2spice renumber off
ext2spice scale off
ext2spice blackbox on
ext2spice subcircuit top on
ext2spice global off
ext2spice format ngspice
ext2spice -o sram_pex.spice sky130_sram_0kbytes_1rw_8x16_8
select top cell
feedback why
puts "Finished ext2spice"
quit -noprompt
EOF
magic_retcode=$?
echo "$(date): Finished ($magic_retcode) GDS to MAG using magic"
exit $magic_retcode
