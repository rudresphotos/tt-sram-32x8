# rudr_sram PDN for a Tiny Tapeout 1x2 tile holding one OpenRAM macro.
#
# TT precheck (pin_check.py) needs every VPWR/VGND pin to be a met4 rectangle >= 1.2 um wide that runs from
# within 10 um of the bottom edge to within 10 um of the top edge. The macro covers most of the tile, and
# met4 inside it is used, so only two columns are free over its full height (checked against the GDS with
# met4_columns.py; the macro LEF met4 OBS is opened there by open_obs_columns.py):
#   VGND stripe, die x 21.58 .. 23.18  (macro-local 15.14 .. 16.74) -> inner ring vssd1 (met3 top/bottom)
#   VPWR stripe, die x 27.95 .. 29.55  (macro-local 21.51 .. 23.11) -> outer ring vccd1 (met3 top/bottom)
# Both columns are also clear of the TT template met4 pins at the top edge (tools/free_columns.py).
# So the grid is exactly one VGND + one VPWR met4 stripe (1.6 um wide, full height), std-cell rails on met1,
# and via3 from the stripes onto the macro ring.

source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET)

define_pdn_grid \
    -name stdcell_grid \
    -starts_with GROUND \
    -voltage_domain CORE \
    -pins met4

# pdngen centres the first stripe at core-left (die x 2.76) + offset: 2.76 + 19.62 = 22.38 -> left edge 21.58 (VGND)
# spacing is edge to edge: 21.58 + 1.6 + 4.77 = 27.95 = VPWR left edge
add_pdn_stripe \
    -grid stdcell_grid \
    -layer met4 \
    -width 1.6 \
    -pitch 150 \
    -offset 19.62 \
    -spacing 4.77 \
    -starts_with GROUND \
    -extend_to_boundary

add_pdn_stripe \
    -grid stdcell_grid \
    -layer $::env(PDN_RAIL_LAYER) \
    -width $::env(PDN_RAIL_WIDTH) \
    -followpins

add_pdn_connect \
    -grid stdcell_grid \
    -layers "$::env(PDN_RAIL_LAYER) met4"

# via3 from the stripes onto the macro ring is added after pdngen (see bottom of file)

# ---------------------------------------------------------------------------------------------------------
# pdngen trims core stripes at the macro boundary, and a core grid cannot via onto macro pins. So after
# pdngen: (1) fill each stripe across the macro (only in the met4-free columns above), add that piece to the
# power pin so the LEF pin is one full-height rectangle, (2) drop 4x4 via3 (M3M4_PR) arrays onto the matching
# macro ring segment at the macro top and bottom.
# Macro-local ring geometry from macro/tt_sram_8x32_wpr1.lef (vccd1 outer ring, vssd1 inner ring, met3 parts).
set ::rudr_rings {
    VPWR { {0.0 1.74} {179.25 180.99} }
    VGND { {3.48 5.22} {175.77 177.51} }
}
proc rudr_connect_macro {} {
    set block [ord::get_db_block]
    set tech [ord::get_db_tech]
    set dbu [$tech getDbUnitsPerMicron]
    set met4 [$tech findLayer met4]
    set via [$tech findVia M3M4_PR]
    set inst [$block findInst mem]
    set mbox [$inst getBBox]
    set mx [$mbox xMin]; set my [$mbox yMin]
    foreach {netname segs} $::rudr_rings {
        set net [$block findNet $netname]
        set sw [lindex [$net getSWires] 0]
        # the stripe = the met4 wire of this net inside the die (one per net)
        set sx1 ""; set gap_lo 0; set gap_hi 0
        foreach w [$sw getWires] {
            if {[$w isVia]} continue
            if {[[$w getTechLayer] getName] != "met4"} continue
            set sx1 [$w xMin]; set sx2 [$w xMax]
            if {[$w yMax] <= [$mbox yMin] + 100} { set gap_lo [$w yMax] }
            if {[$w yMin] >= [$mbox yMax] - 100} { set gap_hi [$w yMin] }
        }
        if {$sx1 == "" || $gap_lo == 0 || $gap_hi == 0} { error "rudr_connect_macro: stripe pieces for $netname not found" }
        odb::dbSBox_create $sw $met4 $sx1 $gap_lo $sx2 $gap_hi "STRIPE"
        foreach bt [$net getBTerms] { foreach bp [$bt getBPins] { odb::dbBox_create $bp $met4 $sx1 $gap_lo $sx2 $gap_hi; break } }
        puts "rudr_connect_macro: $netname stripe filled x $sx1..$sx2 y $gap_lo..$gap_hi"
        foreach seg $segs {
            set ry [expr {$my + round([lindex $seg 0] * $dbu)}]
            foreach dy {0.27 0.67 1.07 1.47} {
                foreach dx {0.2 0.6 1.0 1.4} {
                    set vx [expr {$sx1 + round($dx * $dbu)}]
                    set vy [expr {$ry + round($dy * $dbu)}]
                    odb::dbSBox_create $sw $via $vx $vy "STRIPE"
                }
            }
            puts "rudr_connect_macro: $netname 16 via3 on ring segment at macro-local y [lindex $seg 0]"
        }
    }
}
if {[info commands rudr_orig_pdngen] eq ""} {
    rename pdngen rudr_orig_pdngen
    proc pdngen {args} {
        rudr_orig_pdngen {*}$args
        rudr_connect_macro
    }
}
