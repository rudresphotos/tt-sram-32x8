#!/usr/bin/env python3
"""Compare a new LibreLane run against the signed-off try9 run.

Checks, in this order, and prints every number it uses:
  0. (only if a macro dir is given, i.e. the macro was rebuilt by flow/build_macro.sh) macro GDS XOR and
     LEF/V bytes vs the committed build/macro/ files
  1. sign-off metrics that must be 0 (DRC, LVS, antenna, power grid, ...)
  2. every metric in try9's final/metrics.json against the new run (exact match)
  3. GDS geometry: KLayout XOR per layer of the new GDS vs the committed gds/<top>.gds, plus pin labels
  4. LEF: text diff vs the committed lef/<top>.lef

usage: python3 flow/compare_try9.py <run dir, e.g. build/runs/repro> [macro dir, e.g. build/macro_runs/repro]
needs: pip package `klayout` (Python module klayout.db)
exit code 0 only if all checks pass.
"""
import difflib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gds_xor import xor_gds  # noqa: E402

TOP = "tt_um_rudresphotos_sram"
MACRO = "tt_sram_8x32_wpr1"
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
    print(f"\n## 3. GDS XOR: {new_gds}\n        vs committed {REF_GDS.relative_to(ROOT)}")
    return xor_gds(new_gds, REF_GDS, TOP, out=print)


def committed(path):
    """The file as committed in git HEAD (build/macro/ may have been overwritten by flow/build_macro.sh)."""
    data = subprocess.run(["git", "-C", str(ROOT), "show", f"HEAD:{path}"], check=True, capture_output=True).stdout
    tmp = Path(tempfile.mkdtemp()) / Path(path).name
    tmp.write_bytes(data)
    return tmp


def check_macro(mdir):
    print(f"\n## 0. Macro from OpenRAM + fix_implants ({mdir}) vs committed build/macro/")
    ok = xor_gds(mdir / f"{MACRO}.gds", committed(f"build/macro/{MACRO}.gds"), MACRO, out=print)
    for ext in ("lef", "orig.lef", "v"):
        same = (mdir / f"{MACRO}.{ext}").read_bytes() == committed(f"build/macro/{MACRO}.{ext}").read_bytes()
        ok &= same
        print(f"  {MACRO}.{ext}: {'byte-identical' if same else 'DIFFERS'}")
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
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    run = Path(sys.argv[1]).resolve()
    new = json.loads((run / "final/metrics.json").read_text())
    ref = json.loads(REF_METRICS.read_text())
    results = {}
    if len(sys.argv) == 3:
        results["macro == committed build/macro"] = check_macro(Path(sys.argv[2]).resolve())
    results |= {
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
