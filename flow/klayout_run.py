"""Run a KLayout macro script the way `klayout -zz -r SCRIPT -rd k=v ...` does, using the klayout Python
package (pip install klayout) instead of the KLayout GUI binary.
usage: python3 flow/klayout_run.py SCRIPT key=value [key=value ...]
"""
import sys
import runpy

script, *pairs = sys.argv[1:]
init = {}
for p in pairs:
    k, v = p.split("=", 1)
    init[k] = v
sys.argv = [script]
runpy.run_path(script, init_globals=init, run_name="__main__")
