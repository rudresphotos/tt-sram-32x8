#!/usr/bin/env python3
"""Compare a new LibreLane run against the signed-off try9 run.

Checks, in this order, and prints every number it uses:
  1. sign-off metrics that must be 0 (DRC, LVS, antenna, power grid, ...)
  2. every metric in try9's final/metrics.json against the new run (exact match)
  3. GDS geometry: KLayout XOR per layer of the new GDS vs the committed gds/<top>.gds, plus pin labels
  4. LEF: text diff vs the committed lef/<top>.lef

usage: python3 flow/compare_try9.py <run dir, e.g. build/runs/repro>
needs: pip package `klayout` (Python module klayout.db)
exit code 0 only if all four checks pass.
"""
import difflib
import json
import sys
from pathlib import Path

TOP = "tt_um_rudresphotos_sram"
ROOT = Path(__file__).resolve().parent.parent
REF_METRICS = ROOT / "flow/reference/try9/metrics.json"
REF_GDS = ROOT / f"gds/{TOP}.gds"
REF_LEF = ROOT / f"lef/{TOP}.lef"

MUST_BE_ZERO = [
    "magic__drc_error__count",
    "magic__illegal_overlap__count",
    "design__lvs_error__count",
    "route__drc_errors",
    "antenna__violating__nets",
    "antenna__violating__pins",
    "design__power_grid_violation__count",
    "design__max_slew_violation__count",
    "design__max_fanout_violation__count",
    "design__max_cap_violation__count",
    "flow__errors__count",
]


def check_signoff(new):
    print("\n## 1. Sign-off metrics (must be 0)")
    ok = True
    for k in MUST_BE_ZERO:
        v = new.get(k, "MISSING")
        good = v == 0
        ok &= good
        print(f"  {'ok ' if good else 'BAD'} {k} = {v}")
    return ok


def check_metrics(new, ref):
    print(f"\n## 2. All try9 metrics, exact match ({len(ref)} metrics)")
    diffs = [(k, ref[k], new.get(k, "MISSING")) for k in ref if ref[k] != new.get(k, "MISSING")]
    extra = [k for k in new if k not in ref]
    for k, r, n in diffs:
        print(f"  DIFF {k}: try9={r}  new={n}")
    if extra:
        print(f"  (new run has {len(extra)} metrics try9 did not have: {', '.join(extra[:10])}{' ...' if len(extra) > 10 else ''})")
    print(f"  {len(ref) - len(diffs)}/{len(ref)} metrics identical")
    return not diffs


def check_xor(new_gds):
    import klayout.db as db

    print(f"\n## 3. GDS XOR: {new_gds}\n        vs committed {REF_GDS.relative_to(ROOT)}")
    la, lb = db.Layout(), db.Layout()
    la.read(str(new_gds))
    lb.read(str(REF_GDS))
    if la.dbu != lb.dbu:
        print(f"  BAD database units differ: {la.dbu} vs {lb.dbu}")
        return False
    ca, cb = la.cell(TOP), lb.cell(TOP)
    if ca is None or cb is None:
        print(f"  BAD top cell {TOP} missing (new: {ca is not None}, ref: {cb is not None})")
        return False

    def layers(ly):
        return {(i.layer, i.datatype): idx for idx, i in ((idx, ly.get_info(idx)) for idx in ly.layer_indexes())}

    pa, pb = layers(la), layers(lb)
    ok = True
    n_layers = 0
    for key in sorted(set(pa) | set(pb)):
        ra = db.Region(ca.begin_shapes_rec(pa[key])) if key in pa else db.Region()
        rb = db.Region(cb.begin_shapes_rec(pb[key])) if key in pb else db.Region()
        ra.merge()
        rb.merge()
        x = ra ^ rb
        n_layers += 1
        if not x.is_empty():
            ok = False
            print(f"  DIFF layer {key[0]}/{key[1]}: {x.count()} XOR polygons, area {x.area() * la.dbu ** 2:.6f} um^2")
        ta = sorted((t.string, t.x, t.y) for t in db.Texts(ca.begin_shapes_rec(pa[key]))) if key in pa else []
        tb = sorted((t.string, t.x, t.y) for t in db.Texts(cb.begin_shapes_rec(pb[key]))) if key in pb else []
        if ta != tb:
            ok = False
            print(f"  DIFF layer {key[0]}/{key[1]}: labels differ ({len(ta)} new vs {len(tb)} ref)")
    print(f"  {n_layers} layers compared: {'XOR empty, labels equal' if ok else 'DIFFERENCES above'}")
    return ok


def check_lef(new_lef):
    print(f"\n## 4. LEF text diff vs committed {REF_LEF.relative_to(ROOT)}")
    a = new_lef.read_text().splitlines()
    b = REF_LEF.read_text().splitlines()
    d = list(difflib.unified_diff(b, a, "committed", "new", lineterm="", n=0))
    if d:
        print("\n".join("  " + line for line in d[:40]))
        print(f"  ({len(d)} diff lines)")
    else:
        print("  identical")
    return not d


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    run = Path(sys.argv[1]).resolve()
    new = json.loads((run / "final/metrics.json").read_text())
    ref = json.loads(REF_METRICS.read_text())
    results = {
        "sign-off metrics": check_signoff(new),
        "metrics == try9": check_metrics(new, ref),
        "GDS XOR == committed": check_xor(run / f"final/gds/{TOP}.gds"),
        "LEF == committed": check_lef(run / f"final/lef/{TOP}.lef"),
    }
    print("\n## Summary")
    for k, v in results.items():
        print(f"  {'PASS' if v else 'FAIL'}  {k}")
    sys.exit(0 if all(results.values()) else 1)


if __name__ == "__main__":
    main()
