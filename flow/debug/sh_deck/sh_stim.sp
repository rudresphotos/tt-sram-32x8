
* Stimulus for setup/hold: data 1 period 10n
* TT process corner
.lib "/home/runner/OpenRAM/sky130A/libs.tech/ngspice/sky130.lib.spice" tt
.include "/home/runner/OpenRAM/technology/sky130/sp_lib/sky130_fd_bd_sram__openram_dff.sp"

* Global Power Supplies
Vvdd vdd 0 1.8

*Nodes gnd and 0 are the same global ground node in ngspice/hspice/xa. Otherwise, this source may be needed.
*Vgnd gnd 0 0.0

* Instantiation of the Master-Slave D-flip-flop
Xsky130_fd_bd_sram__openram_dff D Q clk vdd gnd sky130_fd_bd_sram__openram_dff

* Generation of the data and clk signals
* (time, data): [(0, 0), (10, 1), (27.5, 0)]
VD D 0 PWL (0n 0.0v 9.975n 0.0v 10.025n 1.8v 27.475n 1.8v 27.525n 0.0v )
* (time, data): [(0, 0), (1.0, 1), (10, 0), (20, 1)]
Vclk clk 0 PWL (0n 0.0v 0.975n 0.0v 1.025n 1.8v 9.975n 1.8v 10.025n 0.0v 19.975n 0.0v 20.025n 1.8v )
.include /tmp/openram_runner_5254_temp/sh_meas.sp
.TEMP 25
.TRAN 10p 40n 0n 10p UIC
.OPTIONS POST=1 RELTOL=0.001 PROBE method=gear ACCT
* probe is used for hspice/xa, while plot is used in ngspice
.plot V(*)
.end

