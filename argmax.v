`timescale 1ns/1ns
module argmax #(parameter  Width = 8)(
  input wire [Width-1:0] c0, //# spikes for neuron 0 (class 0)
  input wire [Width-1:0] c1, //# spikes for neuron 1 (class 0)
  output wire pred_bit   //prediction: 0 or 1
);
  assign pred_bit = (c1 > c0);
endmodule
