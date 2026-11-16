`timescale 1ns/1ps
// Gate-level check of the finished TT tile netlist (LibreLane final pnl) + OpenRAM behavioural SRAM model.
// Proves the TT pin -> SRAM pin wiring: write all 32 addresses through ui/uio, read back on uo.
// Two passes (pattern, inverted pattern), with a unique byte per address so aliasing would show.
module tb_gl;
  reg  [7:0] ui_in = 8'b0100_0000;   // csb (ui[6]) high = idle, ui[7] = 0
  reg  [7:0] uio_in = 8'h00;
  wire [7:0] uo_out, uio_out, uio_oe;
  reg clk = 0, rst_n = 1, ena = 1;
  wire VPWR = 1'b1, VGND = 1'b0;

  tt_um_rudresphotos_sram dut (
      .VPWR(VPWR), .VGND(VGND),
      .ui_in(ui_in), .uo_out(uo_out), .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
      .ena(ena), .clk(clk), .rst_n(rst_n));

  always #20 clk = ~clk;   // 40 ns period, as in the transistor-level sims

  function [7:0] pat(input integer a, input integer pass);
    pat = (((a << 3) | (7 - (a & 7))) & 8'hFF) ^ (pass ? 8'hFF : 8'h00);
  endfunction

  integer a, pass, errors = 0, checks = 0;
  initial begin
    repeat (2) @(negedge clk);
    for (pass = 0; pass < 2; pass = pass + 1) begin
      for (a = 0; a < 32; a = a + 1) begin           // write: csb=0, web=0
        @(negedge clk); ui_in = {1'b0, 1'b0, 1'b0, a[4:0]}; uio_in = pat(a, pass);
      end
      for (a = 0; a < 32; a = a + 1) begin           // read: csb=0, web=1
        @(negedge clk); ui_in = {1'b0, 1'b0, 1'b1, a[4:0]};
        @(posedge clk); @(posedge clk); #1;           // data valid after the cycle that does the read
        checks = checks + 1;
        if (uo_out !== pat(a, pass)) begin
          errors = errors + 1;
          $display("BAD pass %0d addr %0d: expected %08b got %08b", pass, a, pat(a, pass), uo_out);
        end
      end
    end
    if (uio_oe !== 8'h00 || uio_out !== 8'h00) begin
      errors = errors + 1; $display("BAD uio_oe=%b uio_out=%b (must be 0: uio pins are inputs)", uio_oe, uio_out);
    end
    $display("gate-level TT-pin test: %0d reads checked, %0d errors -> %s", checks, errors, errors ? "FAIL" : "PASS");
    $finish;
  end
endmodule
