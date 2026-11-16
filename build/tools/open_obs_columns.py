# klayout -zz -r open_obs_columns.py -rd lef_in=<in.lef> -rd lef_out=<out.lef> -rd cols="14.84,17.04;50.41,52.61"
# Rewrites the LEF met4 OBS so the given x-columns (macro-local um) are free, full height.
# The columns were checked against the real GDS: no met4 shapes within 0.3 um (met4 min spacing).
import re
import pya

text = open(lef_in).read()
m = re.search(r"(   LAYER  met4 ;\n)((?:      RECT .*\n)+)(   END)", text)
assert m, "met4 OBS block not found"
rects = [list(map(float, l.split()[1:5])) for l in m.group(2).strip().splitlines()]
dbu = 0.001
reg = pya.Region()
for x1, y1, x2, y2 in rects:
    reg.insert(pya.Box(round(x1 / dbu), round(y1 / dbu), round(x2 / dbu), round(y2 / dbu)))
reg.merge()
for c in cols.split(";"):
    a, b = map(float, c.split(","))
    reg -= pya.Region(pya.Box(round(a / dbu), round(-10 / dbu), round(b / dbu), round(300 / dbu)))
# split the remaining OBS area into rectangles
out = []
for poly in reg.each():
    for part in pya.Region(poly).decompose_trapezoids_to_region(pya.Polygon.TD_htrapezoids).each():
        b = part.bbox()
        assert pya.Region(part).area() == b.area(), "non-rectangular piece"
        out.append(b)
lines = "".join("      RECT  %.3f %.3f %.3f %.3f ;\n" % (b.left * dbu, b.bottom * dbu, b.right * dbu, b.top * dbu) for b in out)
text = text[:m.start(2)] + lines + text[m.end(2):]
open(lef_out, "w").write(text)
print("met4 OBS rects: %d -> %d, columns opened: %s" % (len(rects), len(out), cols))
