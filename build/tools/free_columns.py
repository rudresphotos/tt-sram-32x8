# klayout -zz -r free_columns.py -rd gds=<macro.gds> -rd def=<tt template def> -rd macro_x=6.44
# Lists die-x intervals where a full-height met4 power stripe can go:
#   - no macro met4 shape within 0.3 um (met4 spacing)  [macro shapes over full macro height]
#   - no TT template met4 pin within 0.3 um
import re
import pya

mx = float(macro_x)
ly = pya.Layout()
ly.read(gds)
top = ly.top_cell()
reg = pya.Region(top.begin_shapes_rec(ly.find_layer(71, 20))).merged()
blocked = []  # die-x intervals in um
for p in reg.each():
    b = p.bbox()
    blocked.append((b.left * ly.dbu + mx - 0.3, b.right * ly.dbu + mx + 0.3, "macro"))

txt = open(def_).read() if False else open(globals()["def"]).read()
units = 1000.0
for m in re.finditer(r"-\s+(\S+)\s+\+\s+NET.*?\+\s+LAYER\s+met4\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\).*?\+\s+PLACED\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)", txt, re.S):
    name, x1, y1, x2, y2, px, py = m.groups()
    a = (int(px) + int(x1)) / units
    b = (int(px) + int(x2)) / units
    blocked.append((a - 0.3, b + 0.3, name))

blocked.sort()
free = []
x = 2.76 + 0.0
for a, b, n in blocked:
    if a > x:
        free.append((x, a))
    x = max(x, b)
if x < 158.24:
    free.append((x, 158.24))
print("free full-height met4 columns (die x, um), width >= 1.3:")
for a, b in free:
    if b - a >= 1.3:
        print("  %.3f .. %.3f  (width %.3f)" % (a, b, b - a))
pins = [(a, b, n) for a, b, n in blocked if n != "macro"]
print("TT met4 pins:", len(pins), "first few:", [(round(a + 0.3, 2), round(b - 0.3, 2), n) for a, b, n in pins[:6]])
