#!/usr/bin/env python3
"""Fixed sky130_custom_dummy: add ONE li1 rectangle that joins both floating pull-down gate nets to the VGND li.
Everything else is copied unchanged (same cell name, footprint, contacts, labels)."""
import sys, klayout.db as k
src, dst = sys.argv[1], sys.argv[2]
ly = k.Layout(); ly.read(src); top = ly.top_cell()
assert top.name == "sky130_custom_dummy", top.name
li = ly.find_layer(67, 20)
before = k.Region(top.begin_shapes_rec(li)).merged().count()
top.shapes(li).insert(k.DBox(0.435, 0.705, 0.640, 1.265))
after = k.Region(top.begin_shapes_rec(li)).merged().count()
ly.write(dst)
print(f"li1 merged polygons: {before} -> {after} (expected 9 -> 7: VGND li + 2 gate li become one)")
