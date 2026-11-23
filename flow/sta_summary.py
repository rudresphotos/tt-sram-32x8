#!/usr/bin/env python3
"""Summarise a LibreLane OpenROAD.STAPostPNR step directory as markdown (numbers copied from the tool output).

  - per corner: setup / hold worst slack and TNS, violation counts (from the step's state_out.json metrics)
  - whether the macro was timed (macro black-box warning in sta.log or not; liberty files read)
  - the worst setup and hold paths over all corners (from <corner>/max.rpt and min.rpt), with every
    point of the worst path of each type printed in full

usage: python3 flow/sta_summary.py STEP_DIR [N_PATHS (default 10)]
"""
import json
import re
import sys
from pathlib import Path

step = Path(sys.argv[1])
N = int(sys.argv[2]) if len(sys.argv) > 2 else 10

metrics = json.loads((step / "state_out.json").read_text()).get("metrics", {})


def m(key, corner):
    return metrics.get(f"{key}__corner:{corner}", "n/a")


corners = sorted({k.split("__corner:")[1] for k in metrics if "__corner:" in k and k.startswith("timing__")})
print(f"# STA summary: {step}\n")

log = (step / "sta.log").read_text(errors="replace") if (step / "sta.log").exists() else ""
blackbox = re.findall(r"module (tt_sram_8x32_wpr1) not found\. Creating black box", log)
libs = sorted(set(re.findall(r"(\S*tt_sram_8x32_wpr1\S*\.lib)", log)))
print("## Macro timing model\n")
print(f"- macro black-boxed in sta.log: {'YES (no macro timing!)' if blackbox else 'no'}")
for lib in libs:
    print(f"- macro liberty in sta.log: `{lib}`")
print()

print("## Per corner (setup = max paths, hold = min paths; ns)\n")
print("| corner | setup WS | setup TNS | setup vio | hold WS | hold TNS | hold vio | max slew vio | max cap vio |")
print("|---|---|---|---|---|---|---|---|---|")
for c in corners:
    print(f"| {c} | {m('timing__setup__ws', c)} | {m('timing__setup__tns', c)} | {m('timing__setup_vio__count', c)} "
          f"| {m('timing__hold__ws', c)} | {m('timing__hold__tns', c)} | {m('timing__hold_vio__count', c)} "
          f"| {m('design__max_slew_violation__count', c)} | {m('design__max_cap_violation__count', c)} |")
print()
for k in ("timing__setup__ws", "timing__setup__tns", "timing__hold__ws", "timing__hold__tns",
          "timing__setup_vio__count", "timing__hold_vio__count"):
    print(f"- overall {k} = {metrics.get(k, 'n/a')}")
print()

PATH_RE = re.compile(r"Startpoint: (?P<sp>.+?)\n.*?Endpoint: (?P<ep>.+?)\n.*?Path Type: (?P<type>\w+)\n(?P<body>.*?)\n\s*(?P<slack>-?\d+\.\d+)\s+slack \((?P<st>MET|VIOLATED)\)", re.S)


def paths(rpt, corner):
    text = rpt.read_text(errors="replace")
    # only the constrained-path section (report_checks -path_delay ...), not -unconstrained
    text = text.split("report_checks -unconstrained")[0]
    for mt in PATH_RE.finditer(text):
        yield {"corner": corner, "sp": mt["sp"].strip(), "ep": mt["ep"].strip(), "slack": float(mt["slack"]),
               "status": mt["st"], "text": mt.group(0)}


for kind, fname in (("setup", "max.rpt"), ("hold", "min.rpt")):
    allp = []
    for rpt in sorted(step.glob(f"*/{fname}")) or sorted(step.glob(fname)):
        corner = rpt.parent.name if rpt.parent != step else "?"
        allp.extend(paths(rpt, corner))
    allp.sort(key=lambda p: p["slack"])
    print(f"## {N} worst {kind} paths over all corners ({len(allp)} reported paths)\n")
    print("| # | corner | slack (ns) | startpoint | endpoint |")
    print("|---|---|---|---|---|")
    for i, p in enumerate(allp[:N], 1):
        print(f"| {i} | {p['corner']} | {p['slack']:.4f} {p['status']} | `{p['sp']}` | `{p['ep']}` |")
    if allp:
        print(f"\nWorst {kind} path in full ({allp[0]['corner']}):\n\n```\n{allp[0]['text']}\n```\n")
    else:
        print("\n(no constrained paths found)\n")
