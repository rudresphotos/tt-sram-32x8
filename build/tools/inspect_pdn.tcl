# usage: openroad -no_init -exit with env ODB set: lists met4 power stripes and via counts per net
read_db $::env(ODB)
foreach n {VPWR VGND} {
  set net [[ord::get_db_block] findNet $n]
  set nv 0
  foreach sw [$net getSWires] { foreach w [$sw getWires] {
    if {[$w isVia]} { incr nv; continue }
    set l [[$w getTechLayer] getName]
    if {$l == "met4"} { puts "$n $l [$w xMin] [$w yMin] [$w xMax] [$w yMax]" }
  } }
  puts "$n vias $nv"
  foreach bt [$net getBTerms] { foreach bp [$bt getBPins] { foreach b [$bp getBoxes] { puts "$n PIN [[$b getTechLayer] getName] [$b xMin] [$b yMin] [$b xMax] [$b yMax]" } } }
}
