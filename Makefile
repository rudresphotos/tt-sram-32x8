# Rebuild the tile. See flow/build.sh for the steps and options.
#   make tile     OpenRAM macro -> fix_implants -> LibreLane -> gate-level test -> TT precheck
#   make macro    only the macro (into build/macro/)
#   make check    tile build compared with the signed-off try9 run
TAG ?= repro

.PHONY: tile macro check
tile:
	flow/build.sh $(TAG)
macro:
	flow/build_macro.sh $(TAG)
check:
	CHECK_TRY9=1 flow/build.sh $(TAG)
