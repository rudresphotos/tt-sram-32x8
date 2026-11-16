/*
 * SPDX-License-Identifier: Apache-2.0
 * Tiny Tapeout wrapper: an OpenRAM SKY130 SRAM (32 words x 8 bits) wired straight to the TT pins.
 *
 *   ui_in[4:0]  addr[4:0]      word address (0..31)
 *   ui_in[5]    web            write enable, ACTIVE LOW (0 = write, 1 = read)
 *   ui_in[6]    csb            chip select,  ACTIVE LOW (0 = access, 1 = idle)
 *   ui_in[7]    spare          keep LOW (drives the macro's unused spare row/column inputs)
 *   uio_in[7:0] din[7:0]       data to write (all 8 uio pins are inputs)
 *   uo_out[7:0] dout[7:0]      data read
 *   clk                        SRAM clock (inputs are captured on the rising edge)
 *
 * The SRAM module (tt_sram_8x32_wpr1) comes from macro/tt_sram_8x32_wpr1.v; LibreLane reads it as a
 * black box. Its power pins (vccd1/vssd1) are hooked to VPWR/VGND by LibreLane (PDN_MACRO_CONNECTIONS).
 */

`default_nettype none

module tt_um_rudresphotos_sram (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [8:0] dout;

  // uio pins are inputs only
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;
  assign uo_out  = dout[7:0];

  tt_sram_8x32_wpr1 mem (
      .clk0      (clk),
      .csb0      (ui_in[6]),
      .web0      (ui_in[5]),
      // Spare row/column inputs: driven from ui_in[7] (keep it LOW on the board) instead of tie cells,
      // because tie cells would have to sit right at the macro pins where there are no placement rows.
      .spare_wen0(ui_in[7]),
      .addr0     ({ui_in[7], ui_in[4:0]}),
      .din0      ({ui_in[7], uio_in}),
      .dout0     (dout)
  );

  // Unused inputs/outputs (keeps the linter quiet)
  wire _unused = &{ena, rst_n, dout[8], 1'b0};

endmodule
