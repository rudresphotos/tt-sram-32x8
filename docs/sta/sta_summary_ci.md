# STA summary: /home/runner/work/tt-sram-32x8/tt-sram-32x8/build/sta/ci

## Macro timing model

- macro black-boxed in sta.log: no

## Per corner (setup = max paths, hold = min paths; ns)

| corner | setup WS | setup TNS | setup vio | hold WS | hold TNS | hold vio | max slew vio | max cap vio |
|---|---|---|---|---|---|---|---|---|
| max_ff_n40C_1v95 | 10.221219715474255 | 0 | 0 | 7.63790829979442 | 0 | 0 | 0 | 8 |
| max_ss_100C_1v60 | 6.912397960786699 | 0 | 0 | 7.550809968781638 | 0 | 0 | 13 | 8 |
| max_tt_025C_1v80 | 9.329802972044916 | 0 | 0 | 7.599637578785591 | 0 | 0 | 0 | 8 |
| min_ff_n40C_1v95 | 10.296260135920168 | 0 | 0 | 7.6576755992623236 | 0 | 0 | 0 | 8 |
| min_ss_100C_1v60 | 7.131291314869362 | 0 | 0 | 7.590825960434537 | 0 | 0 | 11 | 8 |
| min_tt_025C_1v80 | 9.464360230078185 | 0 | 0 | 7.624640690185706 | 0 | 0 | 0 | 8 |
| nom_ff_n40C_1v95 | 10.25530089875887 | 0 | 0 | 7.64787277376685 | 0 | 0 | 0 | 8 |
| nom_ss_100C_1v60 | 7.017822965829888 | 0 | 0 | 7.570920993307687 | 0 | 0 | 11 | 8 |
| nom_tt_025C_1v80 | 9.44736049464434 | 0 | 0 | 7.61221507374268 | 0 | 0 | 0 | 8 |

- overall timing__setup__ws = 6.912397960786699
- overall timing__setup__tns = 0
- overall timing__hold__ws = 7.550809968781638
- overall timing__hold__tns = 0
- overall timing__setup_vio__count = 0
- overall timing__hold_vio__count = 0

## 10 worst setup paths over all corners (234 reported paths)

| # | corner | slack (ns) | startpoint | endpoint |
|---|---|---|---|---|
| 1 | max_ss_100C_1v60 | 6.9124 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[6] (output port clocked by clk)` |
| 2 | max_ss_100C_1v60 | 6.9241 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[2] (output port clocked by clk)` |
| 3 | max_ss_100C_1v60 | 6.9284 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[4] (output port clocked by clk)` |
| 4 | max_ss_100C_1v60 | 6.9313 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[3] (output port clocked by clk)` |
| 5 | max_ss_100C_1v60 | 6.9499 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[5] (output port clocked by clk)` |
| 6 | max_ss_100C_1v60 | 6.9855 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[7] (output port clocked by clk)` |
| 7 | max_ss_100C_1v60 | 6.9907 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[1] (output port clocked by clk)` |
| 8 | nom_ss_100C_1v60 | 7.0178 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[6] (output port clocked by clk)` |
| 9 | nom_ss_100C_1v60 | 7.0229 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[3] (output port clocked by clk)` |
| 10 | nom_ss_100C_1v60 | 7.0280 MET | `mem (falling edge-triggered flip-flop clocked by clk)` | `uo_out[2] (output port clocked by clk)` |

Worst setup path in full (max_ss_100C_1v60):

```
Startpoint: mem (falling edge-triggered flip-flop clocked by clk)
Endpoint: uo_out[6] (output port clocked by clk)
Path Group: clk
Path Type: max

Fanout         Cap        Slew       Delay        Time   Description
---------------------------------------------------------------------------------------------
                                 20.000000   20.000000   clock clk (fall edge)
                                  0.000000   20.000000   clock source latency
     1    0.067693    0.290212    0.224013   20.224012 v clk (in)
                                                         clk (net)
                      0.387828    0.000000   20.224012 v mem/clk0 (tt_sram_8x32_wpr1)
     1    0.082469    0.912548    4.598835   24.822849 ^ mem/dout0[6] (tt_sram_8x32_wpr1)
                                                         uo_out[6] (net)
                      0.684411    0.014753   24.837601 ^ uo_out[6] (out)
                                             24.837601   data arrival time

                                 40.000000   40.000000   clock clk (rise edge)
                                  0.000000   40.000000   clock network delay (propagated)
                                 -0.250000   39.750000   clock uncertainty
                                  0.000000   39.750000   clock reconvergence pessimism
                                 -8.000000   31.750000   output external delay
                                             31.750000   data required time
---------------------------------------------------------------------------------------------
                                             31.750000   data required time
                                            -24.837601   data arrival time
---------------------------------------------------------------------------------------------
                                              6.912398   slack (MET)
```

## 10 worst hold paths over all corners (234 reported paths)

| # | corner | slack (ns) | startpoint | endpoint |
|---|---|---|---|---|
| 1 | max_ss_100C_1v60 | 7.5508 MET | `ui_in[4] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 2 | max_ss_100C_1v60 | 7.5528 MET | `ui_in[3] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 3 | nom_ss_100C_1v60 | 7.5709 MET | `ui_in[4] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 4 | nom_ss_100C_1v60 | 7.5735 MET | `ui_in[3] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 5 | min_ss_100C_1v60 | 7.5908 MET | `ui_in[4] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 6 | min_ss_100C_1v60 | 7.5930 MET | `ui_in[3] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 7 | max_tt_025C_1v80 | 7.5996 MET | `ui_in[4] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 8 | max_ss_100C_1v60 | 7.6000 MET | `ui_in[1] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 9 | max_tt_025C_1v80 | 7.6009 MET | `ui_in[3] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |
| 10 | nom_tt_025C_1v80 | 7.6122 MET | `ui_in[4] (input port clocked by clk)` | `mem (falling edge-triggered flip-flop clocked by clk)` |

Worst hold path in full (max_ss_100C_1v60):

```
Startpoint: ui_in[4] (input port clocked by clk)
Endpoint: mem (falling edge-triggered flip-flop clocked by clk)
Path Group: clk
Path Type: min

Fanout         Cap        Slew       Delay        Time   Description
---------------------------------------------------------------------------------------------
                                  0.000000    0.000000   clock clk (rise edge)
                                  0.000000    0.000000   clock network delay (propagated)
                                  8.000000    8.000000 v input external delay
     1    0.027692    0.121624    0.081150    8.081150 v ui_in[4] (in)
                                                         ui_in[4] (net)
                      0.162187    0.000000    8.081150 v mem/addr0[4] (tt_sram_8x32_wpr1)
                                              8.081150   data arrival time

                                  0.000000    0.000000   clock clk (rise edge)
                                  0.000000    0.000000   clock source latency
     1    0.067693    0.487313    0.361340    0.361340 ^ clk (in)
                                                         clk (net)
                      0.650269    0.000000    0.361340 ^ mem/clk0 (tt_sram_8x32_wpr1)
                                  0.250000    0.611340   clock uncertainty
                                  0.000000    0.611340   clock reconvergence pessimism
                                 -0.081000    0.530340   library hold time
                                              0.530340   data required time
---------------------------------------------------------------------------------------------
                                              0.530340   data required time
                                             -8.081150   data arrival time
---------------------------------------------------------------------------------------------
                                              7.550810   slack (MET)
```

