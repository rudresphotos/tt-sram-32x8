# klayout -zz -r fix_implants.py -rd gds_in=<macro.gds> -rd gds_out=<fixed.gds>
#
# TT precheck KLayout FEOL (sky130A_mr.drc) flags same-layer spacing violations in the OpenRAM cells:
#   MR_nsdm.SP.1 / MR_psdm.SP.1  nsdm/psdm spacing < 0.38 um (periphery rule)
#   npc.2                        npc spacing < 0.27 um
# Fix (same idea as Staf Verhaegen's TT SRAM generator post-processing): fill gaps narrower than the rule
# with the same layer ("closing"), never where the opposite implant is. The fill shapes are added flat to
# the macro top cell; nothing is removed.
import pya

ly = pya.Layout()
ly.read(gds_in)
top = ly.top_cell()

def flat(layer, dt):
    li = ly.find_layer(layer, dt)
    if li is None:
        return pya.Region(), ly.layer(layer, dt)
    return pya.Region(top.begin_shapes_rec(li)).merged(), li

nsdm, li_n = flat(93, 44)
psdm, li_p = flat(94, 20)
npc, li_npc = flat(95, 20)

def close(reg, space_um):
    d = int(round(space_um / 2 / ly.dbu)) + 1   # half the min space (+1 dbu): fills gaps < space
    return reg.sized(d).sized(-d)

report = []
# implants: fill same-type gaps, but never onto the opposite implant (keep 0 overlap)
fill_n = (close(nsdm, 0.38) - nsdm) - psdm
# psdm gaps: in OpenRAM the p-tap psdm patches sit inside an nsdm sheet (they already overlap it in the
# original layout), so a psdm gap may contain nsdm but no device. Fill it as long as the fill stays
# >= 0.13 um from any n-type diff/tap and from poly (so no transistor or gate changes its doping).
diff, _ = flat(65, 20)
tap, _ = flat(65, 44)
poly, _ = flat(66, 20)
active = (diff + tap).merged()
n_active = (active & nsdm) - psdm
keepout_p = (n_active.sized(int(round(0.13 / ly.dbu))) + poly.sized(int(round(0.13 / ly.dbu)))).merged()
fill_p = (close(psdm, 0.38) - psdm) - keepout_p
fill_npc = close(npc, 0.27) - npc

for name, reg, li in (("nsdm", fill_n, li_n), ("psdm", fill_p, li_p), ("npc", fill_npc, li_npc)):
    reg = reg.merged()
    top.shapes(li).insert(reg)
    report.append("%s: added %d fill polygons, %.4f um^2" % (name, reg.count(), reg.area() * ly.dbu * ly.dbu))

# Two diagonal (corner-to-corner) psdm gaps that the closing cannot bridge without coming within 0.13 um of
# an n-type diff. Bridge them by hand with one 0.38 um wide psdm rectangle each (cell-local coordinates,
# read from the layout: see notes). Both rectangles stay >= 0.13 um from the n-diff next to them.
manual = {
    # cell: [(x1, y1, x2, y2)]  um
    "tt_sram_8x32_wpr1_control_logic_rw": [(19.435, 42.29, 19.935, 43.21)],
    "tt_sram_8x32_wpr1_pnand2_0": [(1.665, -0.25, 2.045, 0.13)],
}
for cname, rects in manual.items():
    c = ly.cell(cname)
    if c is None:
        report.append("manual psdm bridge: cell %s not found (skipped)" % cname)
        continue
    for r in rects:
        c.shapes(li_p).insert(pya.DBox(*r))
    report.append("manual psdm bridge: %s %s" % (cname, rects))

# sanity: no nsdm/psdm overlap after the fix
n2, _ = flat(93, 44)
p2, _ = flat(94, 20)
ov = n2 & p2
report.append("nsdm & psdm overlap after fix: %d polygons" % ov.count())
ly.write(gds_out)
print("\n".join(report))
