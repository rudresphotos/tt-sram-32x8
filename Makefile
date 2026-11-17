# Rebuild and sign off the tile. See flow/build.sh, flow/characterize.sh, flow/sta.sh and docs/timing_signoff.md.
#   make tile     OpenRAM macro -> fix_implants -> LibreLane -> gate-level test -> TT precheck   (D1)
#   make check    tile build compared with the signed-off try9 run
#   make macro    only the macro (into build/macro/)
#   make lib      ngspice .lib of the macro at TT, SS, FF (hours; CI: push to a char/* branch)   (D2)
#   make sta      LibreLane sign-off STA of the built tile with the macro .lib, 9 corners          (D3)
TAG ?= repro

.PHONY: tile macro check lib sta
tile:
	flow/build.sh $(TAG)
macro:
	flow/build_macro.sh $(TAG)
check:
	CHECK_TRY9=1 flow/build.sh $(TAG)
lib:
	for c in TT SS FF; do flow/characterize.sh $$c build/macro_runs/$(TAG)/raw/tt_sram_8x32_wpr1.sp || exit 1; done
sta:
	flow/sta.sh $(TAG)
