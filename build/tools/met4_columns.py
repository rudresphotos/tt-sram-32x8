# klayout -zz -r met4_columns.py -rd gds=<macro.gds>
# For each TT power stripe x-range (macro-local coords), list met4 (71/20) shapes of the flattened macro that overlap it.
import pya

ly = pya.Layout()
ly.read(gds)
top = ly.top_cell()
li = ly.find_layer(71, 20)
reg = pya.Region(top.begin_shapes_rec(li)).merged()
print("macro bbox um:", top.dbbox())
print("met4 polygons (merged):", reg.count())
macro_x = 6.44
stripes = {}
for i, x in enumerate([18.28, 57.15, 96.02, 134.89]):
    stripes["VPWR%d" % i] = x
    stripes["VGND%d" % i] = x + 3.30
for name, gx in stripes.items():
    lx = gx - macro_x
    box = pya.DBox(lx - 0.3, -1, lx + 1.6 + 0.3, 200)  # stripe width 1.6 um + 0.3 um spacing margin
    hits = reg & pya.Region(box.to_itype(ly.dbu))
    spans = sorted(set((round(p.bbox().bottom * ly.dbu, 2), round(p.bbox().top * ly.dbu, 2)) for p in hits.each()))
    print("%-6s global x %.2f (local %.2f): %d met4 shapes overlap; y spans %s" % (name, gx, lx, hits.count(), spans[:12]))
