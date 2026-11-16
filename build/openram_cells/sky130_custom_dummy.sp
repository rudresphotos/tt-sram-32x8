* sky130_custom_dummy, FIXED 17 Nov 2026: pull-down/pull-up gates tied to VGND by one li1 rectangle
* (0.435,0.705)-(0.640,1.265) um. Original (floating gates a_30_347#, a_30_233#) kept in ~/work/dummyfix/backup.
* SPICE3 file created from sky130_custom_dummy.ext - technology: sky130A

.subckt sky130_custom_dummy BL BR WL VPWR VGND
X0 a_290_377# VGND VPWR VPWR sky130_fd_pr__pfet_01v8 ad=0.1218 pd=1.42 as=0.0882 ps=0.84 w=0.42 l=0.15
X1 a_56_159# WL BR VGND sky130_fd_pr__nfet_01v8 ad=0.0777 pd=0.79 as=0.1218 ps=1.42 w=0.42 l=0.15
X2 a_56_377# VGND VGND VGND sky130_fd_pr__nfet_01v8 ad=0.0756 pd=0.78 as=0.09795 ps=0.915 w=0.42 l=0.15
X3 VPWR VGND a_290_176# VPWR sky130_fd_pr__pfet_01v8 ad=0.0882 pd=0.84 as=0.1197 ps=1.41 w=0.42 l=0.15
X4 VGND VGND a_56_159# VGND sky130_fd_pr__nfet_01v8 ad=0.09795 pd=0.915 as=0.0777 ps=0.79 w=0.42 l=0.15
X5 BL WL a_56_377# VGND sky130_fd_pr__nfet_01v8 ad=0.1428 pd=1.52 as=0.0756 ps=0.78 w=0.42 l=0.15
.ends
