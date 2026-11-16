"""Layout equivalence check of two GDS files with KLayout: for every (layer, datatype) the merged shapes of the
flattened top cell are XORed (must be empty) and the text labels (string, x, y) must be equal.
Byte equality is not required: GDS files also hold write dates and tool-chosen cell names.
usage: python3 flow/gds_xor.py NEW.gds REF.gds [TOPCELL]     exit 0 = equivalent, 1 = differences
"""
import sys


def xor_gds(new_gds, ref_gds, top=None, out=print):
    import klayout.db as db

    la, lb = db.Layout(), db.Layout()
    la.read(str(new_gds))
    lb.read(str(ref_gds))
    if la.dbu != lb.dbu:
        out(f"  BAD database units differ: {la.dbu} vs {lb.dbu}")
        return False
    ca = la.cell(top) if top else la.top_cell()
    cb = lb.cell(top) if top else lb.top_cell()
    if ca is None or cb is None:
        out(f"  BAD top cell missing (new: {ca is not None}, ref: {cb is not None})")
        return False
    if ca.name != cb.name:
        out(f"  BAD top cell names differ: {ca.name} vs {cb.name}")
        return False

    def layers(ly):
        return {(ly.get_info(i).layer, ly.get_info(i).datatype): i for i in ly.layer_indexes()}

    pa, pb = layers(la), layers(lb)
    ok = True
    for key in sorted(set(pa) | set(pb)):
        ra = db.Region(ca.begin_shapes_rec(pa[key])) if key in pa else db.Region()
        rb = db.Region(cb.begin_shapes_rec(pb[key])) if key in pb else db.Region()
        x = ra.merged() ^ rb.merged()
        if not x.is_empty():
            ok = False
            out(f"  DIFF layer {key[0]}/{key[1]}: {x.count()} XOR polygons, area {x.area() * la.dbu ** 2:.6f} um^2")
        ta = sorted((t.string, t.x, t.y) for t in db.Texts(ca.begin_shapes_rec(pa[key]))) if key in pa else []
        tb = sorted((t.string, t.x, t.y) for t in db.Texts(cb.begin_shapes_rec(pb[key]))) if key in pb else []
        if ta != tb:
            ok = False
            out(f"  DIFF layer {key[0]}/{key[1]}: labels differ ({len(ta)} new vs {len(tb)} ref)")
    n = len(set(pa) | set(pb))
    out(f"  top cell {ca.name}: {n} layers compared: {'XOR empty, labels equal' if ok else 'DIFFERENCES above'}")
    return ok


if __name__ == "__main__":
    a, b, *rest = sys.argv[1:]
    sys.exit(0 if xor_gds(a, b, rest[0] if rest else None) else 1)
