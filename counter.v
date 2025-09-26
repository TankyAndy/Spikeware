`timescale 1ns/1ns
module counter #(parameter  Width = 8)(
  input wire clk, //clock
  input wire rst, //synchronous reset
  input wire en, //enable
  input wire sig, //increment signal
  output reg [Width-1:0] q //counter value
);
  always @(posedge clk) begin
    if (rst) begin
      q <= {Width{1'b0}}; //q = 0
    end else begin
      if (en) begin //if counter enabled, allow incrementing
        if (sig) begin //if sig on and posedge clk, increment counter
          q <= q + 1'b1;
        end
      end
    end
  end
endmodule
