#!/usr/bin/env python3
"""Make OpenRAM's sky130 netlist consistent for ngspice with the SKY130 models' `.option scale=1.0u`.

OpenRAM writes transistor sizes unitless (W=0.74 L=0.15, meaning um under the PDK's scale=1.0u), except the
sky130_custom_nand3_dec cell from OpenRAM's sp_lib, which says W=0.74u L=0.15u. Under scale=1.0u those become
0.74e-12 m and ngspice stops with "could not find a valid modelname". This drops the 'u' on W/L of transistor
lines only, i.e. the same device size in the same units as the rest of the netlist. Prints every changed line.

usage: python3 flow/normalize_units.py IN.sp OUT.sp EXPECTED_CHANGES
"""
import re
import sys

src, dst, expected = sys.argv[1], sys.argv[2], int(sys.argv[3])
fet = re.compile(r"sky130_fd_pr__[np]fet_\w+", re.I)
wl = re.compile(r"\b([WL])=([0-9.]+)u\b", re.I)
out, changed = [], 0
for n, line in enumerate(open(src), 1):
    if not line.lstrip().startswith("*") and fet.search(line) and wl.search(line):
        new = wl.sub(r"\1=\2", line)
        print(f"  line {n}: {line.strip()}  ->  {new.strip()}")
        line = new
        changed += 1
    out.append(line)
open(dst, "w").writelines(out)
print(f"{changed} transistor lines normalized (expected {expected})")
sys.exit(0 if changed == expected else 1)
