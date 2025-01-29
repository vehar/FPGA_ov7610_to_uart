`timescale 1ns / 1ps

module input_reset_buf(
  input      i_clk,     //  input clock domain signal
  input      i_por,     //  input power reset signal
  output reg o_rst      //  output reset signal
  );

  reg r_por;

  always @(posedge i_clk) begin
    r_por <= i_por;
  end

  always @(posedge i_clk) begin
    o_rst <= !r_por;
  end
  
endmodule
