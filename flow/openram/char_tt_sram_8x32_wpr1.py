# OpenRAM characterization config for the tile's macro (used by flow/characterize.sh with OpenRAM's sram_char.py).
# Same SRAM organisation as tt_sram_8x32_wpr1.py, plus:
#  - spice simulation with ngspice instead of OpenRAM's analytical (estimated) delay model
#  - exactly one PVT corner per run, chosen by CHAR_CORNER, matching LibreLane's three corners:
#      TT 1.80 V 25 C  (nom_tt_025C_1v80)   SS 1.60 V 100 C  (ss_100C_1v60)   FF 1.95 V -40 C  (ff_n40C_1v95)
#  - input slew / output load table indices moved from OpenRAM's defaults (slew 1.25-40 ps, load 1.7-28 fF)
#    to the range the tile's std cells actually drive / present (0.05-0.8 ns, 3.4-55 fF), so STA reads the
#    table instead of extrapolating far outside it.
import os
exec(open(os.path.join(os.path.dirname(__file__), 'tt_sram_8x32_wpr1.py')).read())

CORNERS = {"TT": ("TT", 1.8, 25), "SS": ("SS", 1.6, 100), "FF": ("FF", 1.95, -40)}
use_specified_corners = [CORNERS[os.environ.get("CHAR_CORNER", "TT")]]
analytical_delay = False
spice_name = "ngspice"
num_sim_threads = int(os.environ.get("CHAR_THREADS", "4"))
slew_scales = [10, 40, 160]      # x rise_time 0.005 ns  -> 0.05, 0.2, 0.8 ns
load_scales = [0.5, 2, 8]        # x dff_in_cap 6.89 fF  -> 3.445, 13.78, 55.12 fF
output_path = "char/{}/".format(os.environ.get("CHAR_CORNER", "TT"))
# sky130_custom_cell storage nets (see its subckt in the macro .sp); read by flow/openram/openram_memchar_storage_names.diff
memchar_storage_names = ("Q", "Qbar")
# s_en is a PORT of the bank subcircuit, so ngspice knows it only by the SRAM top-level net name s_en0
# (OpenRAM's default "X{name}.xbank0.s_en" points inside the bank and the s_en measurement fails).
sen_format = "X{name}{hier_sep}s_en"
# characterize.sh already runs OpenRAM inside the Nix shell; don't start a new `nix develop` for every ngspice call
use_nix = False
# macro size for the .lib area (set by characterize.sh from the macro LEF SIZE); read by openram_memchar_area.diff
memchar_width = float(os.environ.get("CHAR_MACRO_W", "0"))
memchar_height = float(os.environ.get("CHAR_MACRO_H", "0"))
