// Custom Module

module sampleClkGen #(
    parameter WIDTH = 16
)(
    input wire clk,
    input wire en,
    input wire nreset,
	input [WIDTH-1:0] data_in, //2 = 12MHz, 63 = 593kHz
	output reg sampClk
);

reg [WIDTH-1:0] counter;

always @(posedge clk)
  begin
    if (!nreset)
      begin
        counter <= 'h0;
        sampClk <= 1'b0;
      end
    else
      begin
        if (counter < data_in) begin
            counter <= counter + 1;
          end
        else begin
            counter <= 'h0;
            sampClk <= ~sampClk;
          end
      end
  end
  
endmodule