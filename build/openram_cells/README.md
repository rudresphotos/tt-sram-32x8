# Fixed OpenRAM dummy cell (`sky130_custom_dummy`)

## Problem
OpenRAM's SKY130 `tech_custom_cell` library ships `sky130_custom_dummy` (in
`technology/sky130/gds_lib` and `sp_lib`). It is the normal custom 6T bitcell with its four storage-node contacts
removed. That leaves two poly gates (each shared by one pull-down NMOS and one pull-up PMOS) **floating**, while the
two access transistors still connect to BL/BR.

OpenRAM places a row of these cells on the replica wordline `rbl_wl` (`Xdummy_row_0`, by design), which turns on
during every access. So on every read and write each bitline sees a path to ground through a pull-down NMOS whose
gate voltage is undefined. In transistor-level simulation of the extracted layout this caused the ff -40 C and
sf 25 C march failures, and every ngspice run reported `singular matrix` warnings from the floating nodes.

## Fix
One li1 rectangle, (0.435, 0.705)-(0.640, 1.265) um in cell coordinates, joins both floating gate nets to the
VGND li strip (`../tools/fix_dummy_cell.py`). After the fix (Magic extraction of the cell):
- pull-down NMOS gates = VGND (always off), pull-up PMOS gates = VGND (they only pull isolated drains);
- access transistors unchanged, so the load on `rbl_wl` and the replica timing are unchanged;
- footprint, contacts, pins and labels unchanged.
`sky130_custom_dummy.sp` is the original netlist with the two floating gate nets renamed to VGND.

The macro was regenerated with this cell installed in OpenRAM (unchanged size config): OpenRAM DRC 0, LVS match,
LEF and Verilog identical to before. The extracted macro has 0 floating-gate nets (before: 202).

| File | MD5 |
|---|---|
| `sky130_custom_dummy.gds` (fixed) | 32bc080d0bb0945e26e246026057e837 |
| `sky130_custom_dummy.sp` (fixed) | 9b2ae3b4bbf2800e258d4386390b7f94 |
| `sky130_custom_dummy.ORIGINAL.gds` (OpenRAM 1.2.50) | d8dd14dc0124ed0fa842ed21b5906dca |
| `sky130_custom_dummy.ORIGINAL.sp` (OpenRAM 1.2.50) | 1a02819c33edbdb72991f6458128941b |

To reproduce: copy the two fixed files over the ones in `~/OpenRAM/technology/sky130/{gds_lib,sp_lib}/`, then
regenerate the macro and run `tools/fix_implants.py` as before.
