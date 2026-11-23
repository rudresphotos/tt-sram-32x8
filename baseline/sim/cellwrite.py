#!/usr/bin/env python3
"""Cell-level write test: one bitcell + OpenRAM write-driver pull-down + extracted bitline C.

Starts with Q=1, then writes 0: wordline on for --wl ns, BL pulled low through the
write driver's NMOS (W=1um), BR left floating at precharge level (as in the real write driver).
Reports final Q / Qbar per corner. A cell that still holds Q=1 after a long wordline pulse
has a STATIC write failure -> no timing/clock change can fix it, only cell/driver sizing.

usage (from ~/sram_work/sim):  python3 cellwrite.py [--wl NS] [--cell sky130_custom_cell]
"""
import argparse, re, subprocess, os

PDK = os.path.join(os.environ.get("PDK_ROOT", os.path.expanduser("~/OpenRAM")), "sky130A/libs.tech/ngspice/sky130.lib.spice")
CORNERS = [("tt", 25), ("ff", -40), ("ff", 100), ("ss", -40), ("ss", 100), ("fs", 25), ("sf", -40), ("sf", 25), ("sf", 100)]
CBL = 19.6  # fF, total extracted capacitance on bl_0 (sum of PEX caps on port_data_0/bl_0)

ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
ap.add_argument("--wl", type=float, default=20.0, help="wordline pulse width in ns (default 20)")
ap.add_argument("--cell", default="sky130_custom_cell", help="bitcell subckt name in netlist/sram_tb.sp")
ap.add_argument("--netlist", default="netlist/sram_tb.sp")
a = ap.parse_args()

os.makedirs("runs", exist_ok=True)
print(f"cell {a.cell}, wordline {a.wl} ns, Cbl {CBL} fF, write 0 into a cell holding 1")
print(f"{'corner':>10}  {'Q end':>6} {'Qbar end':>8}  result")
for corner, temp in CORNERS:
    name = f"runs/cellwrite_{corner}{temp}C"
    sp = f"""* cell write test {corner} {temp}C
.lib "{PDK}" {corner}
.temp {temp}
.include "{a.netlist}"
Vvdd vdd 0 1.8
Xcell bl br wl vdd 0 {a.cell}
Cbl bl 0 {CBL}f
Cbr br 0 {CBL}f
* write-driver pull-down on BL (X_15 in sky130_fd_bd_sram__openram_write_driver), gate on during the write
Xpd bl en 0 0 sky130_fd_pr__nfet_01v8 W=1 L=0.15
Ven en 0 PWL (0 0 1n 0 1.05n 1.8 {1+a.wl}n 1.8 {1.05+a.wl}n 0)
Vwl wl 0 PWL (0 0 1n 0 1.05n 1.8 {1+a.wl}n 1.8 {1.05+a.wl}n 0)
.ic v(bl)=1.8 v(br)=1.8 v(xcell.q)=1.8 v(xcell.qbar)=0
.meas tran qend FIND v(xcell.q) AT={a.wl+5}n
.meas tran qbend FIND v(xcell.qbar) AT={a.wl+5}n
.meas tran qmin MIN v(xcell.q) FROM=1n TO={1+a.wl}n
.tran 10p {a.wl+6}n UIC
.end
"""
    open(name + ".sp", "w").write(sp)
    subprocess.run(["ngspice", "-b", name + ".sp", "-o", name + ".log"], capture_output=True)
    log = open(name + ".log").read()
    v = {k: float(x) for k, x in re.findall(r"^(qend|qbend|qmin)\s*=\s*([-+\d.eE]+)", log, re.M)}
    if len(v) < 3:
        print(f"{corner+str(temp)+'C':>10}  simulation error, see {name}.log")
        continue
    ok = v["qend"] < 0.9 and v["qbend"] > 0.9
    print(f"{corner+' '+str(temp)+'C':>10}  {v['qend']:6.2f} {v['qbend']:8.2f}  "
          f"{'WRITTEN' if ok else 'FAILED (cell kept old value, Q dipped to %.2f V)' % v['qmin']}")
