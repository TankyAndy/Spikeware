`timescale 1ns/1ns
module rom #(
  parameter DEPTH = 1, //number of rows
  parameter WIDTH = 8, //bits per row
  parameter A_WIDTH = 8,   // address width
  parameter FILE = "" //hex file
)(
  input wire clk, //clock
  input wire en, //enable read
  input wire [A_WIDTH-1:0] addr, //address
  output reg [WIDTH-1:0] dout //data output
);
  reg [WIDTH-1:0] mem [0:DEPTH-1]; //memory 2D array
  initial if (FILE != "") $readmemh(FILE, mem); //load file content into memory
  always @(posedge clk) begin
    if (en) begin
      dout <= mem[addr]; //read memory at index addr and store that row into dout
    end
  end
endmodule
