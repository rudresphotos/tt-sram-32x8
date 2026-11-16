#!/usr/bin/env python3
"""Sanity check of a Liberty (.lib) file of the SRAM macro: prints what is in it and fails on obvious errors.

Prints: library units, operating conditions, cell area, every pin with direction/capacitance, and for every
timing arc the min..max of its tables (setup/hold on inputs vs clk, clk->dout delay and transition), plus
min_period / min_pulse_width.
Fails (exit 1) if: a time/cap unit is missing, no clk->dout arc, no setup or hold arc, any table value is NaN,
or a clk->dout delay is <= 0.

usage: python3 flow/lib_sanity.py FILE.lib [FILE.lib ...]
"""
import math
import re
import sys

TOKEN = re.compile(r'"(?:[^"\\]|\\.)*"|[{}();:,]|[^\s{}();:,"]+')


def tokenize(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"\\\n", " ", text)
    return TOKEN.findall(text)


class Group:
    def __init__(self, kind, args):
        self.kind, self.args, self.attrs, self.groups = kind, args, {}, []

    def find(self, kind):
        return [g for g in self.groups if g.kind == kind]


def parse(tokens):
    """Liberty grammar: name ( args ) { ... }  |  name : value ;  |  name ( args ) ;"""
    root = Group("root", [])
    stack = [root]
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t == "}":
            stack.pop()
            i += 1
            continue
        if t == ";":
            i += 1
            continue
        name = t
        nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
        if nxt == ":":
            val = []
            j = i + 2
            while tokens[j] != ";" and tokens[j] != "}":
                val.append(tokens[j])
                j += 1
            stack[-1].attrs[name] = " ".join(val).strip('"')
            i = j
        elif nxt == "(":
            args = []
            j = i + 2
            while tokens[j] != ")":
                if tokens[j] != ",":
                    args.append(tokens[j].strip('"'))
                j += 1
            j += 1
            if j < len(tokens) and tokens[j] == "{":
                g = Group(name, args)
                stack[-1].groups.append(g)
                stack.append(g)
                i = j + 1
                continue
            lst = stack[-1].attrs.setdefault(name, [])
            if isinstance(lst, list):
                lst.append(args)
            i = j
        else:
            i += 1
    return root


def nums(args):
    out = []
    for a in args:
        for x in a.replace("\\", " ").split(","):
            x = x.strip()
            if x:
                out.append(float(x))
    return out


def table_values(g):
    v = g.attrs.get("values")
    return nums(v[0]) if isinstance(v, list) and v else []


def check(path):
    print(f"\n### {path}")
    lib = parse(tokenize(open(path).read())).groups[0]
    ok = True
    for u in ("time_unit", "capacitive_load_unit", "voltage_unit", "current_unit", "leakage_power_unit"):
        v = lib.attrs.get(u)
        print(f"  {u:22s} {v[0] if isinstance(v, list) else v}")
        if u in ("time_unit", "capacitive_load_unit") and not v:
            print(f"  BAD missing {u}")
            ok = False
    for k in ("nom_process", "nom_voltage", "nom_temperature", "default_operating_conditions"):
        print(f"  {k:22s} {lib.attrs.get(k)}")
    for oc in lib.find("operating_conditions"):
        print(f"  operating_conditions({oc.args[0]}): process {oc.attrs.get('process')} voltage {oc.attrs.get('voltage')} temperature {oc.attrs.get('temperature')}")
    for tmpl in lib.find("lu_table_template"):
        idx = {k: nums(v[0]) for k, v in tmpl.attrs.items() if k.startswith("index_")}
        print(f"  table template {tmpl.args[0]}: " + "; ".join(f"{tmpl.attrs.get('variable_' + k[-1])} = {v}" for k, v in idx.items()))

    cells = lib.find("cell")
    if not cells:
        print("  BAD no cell")
        return False
    for cell in cells:
        print(f"  cell {cell.args[0]}: area {cell.attrs.get('area')}")
        pins = []
        for b in cell.find("bus") + cell.find("pin"):
            sub = b.find("pin") or [b]
            pins.append((b, sub[0]))
        arcs = {"setup": [], "hold": [], "clk_to_q": []}
        for b, p in pins:
            g = b
            print(f"    {g.kind} {g.args[0]:8s} dir {g.attrs.get('direction'):6s} cap {g.attrs.get('capacitance', '-')}")
            for k in ("min_period", "min_pulse_width_high", "min_pulse_width_low"):
                if k in g.attrs:
                    print(f"      {k} = {g.attrs[k]}")
            for t in g.find("timing") + [t for pp in g.find("pin") for t in pp.find("timing")]:
                ttype = t.attrs.get("timing_type", "combinational")
                rel = t.attrs.get("related_pin")
                for tab in t.groups:
                    vals = table_values(tab)
                    if not vals:
                        continue
                    if any(math.isnan(x) for x in vals):
                        print(f"      BAD NaN in {tab.kind}")
                        ok = False
                    print(f"      {ttype:14s} vs {rel:5s} {tab.kind:18s} min {min(vals):.4f} max {max(vals):.4f}  ({len(vals)} entries)")
                    if ttype.startswith("setup"):
                        arcs["setup"].append(vals)
                    elif ttype.startswith("hold"):
                        arcs["hold"].append(vals)
                    elif tab.kind in ("cell_rise", "cell_fall"):
                        arcs["clk_to_q"].append(vals)
                        if min(vals) <= 0:
                            print(f"      BAD clk->{g.args[0]} delay <= 0")
                            ok = False
        for k, v in arcs.items():
            if not v:
                print(f"  BAD no {k} arc")
                ok = False
        if arcs["clk_to_q"]:
            allv = [x for t in arcs["clk_to_q"] for x in t]
            print(f"  SUMMARY clk->dout delay {min(allv):.4f} .. {max(allv):.4f} (time unit {lib.attrs.get('time_unit')})")
        for k in ("setup", "hold"):
            if arcs[k]:
                allv = [x for t in arcs[k] for x in t]
                print(f"  SUMMARY {k} {min(allv):.4f} .. {max(allv):.4f}")
    print(f"  => {'OK' if ok else 'PROBLEMS above'}")
    return ok


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(0 if all([check(f) for f in sys.argv[1:]]) else 1)
