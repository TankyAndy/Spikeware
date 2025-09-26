`timescale 1ns/1ns
module snn_two_layer #(
  parameter W_WIDTH = 16, //weight width
  parameter V_WIDTH = 32, //voltage width
  parameter N_IN = 9, //# input neuonrs (input layer)
  parameter N_HID = 6, //#number of neurons per hidden layer
  parameter N_OUT = 2 //# output neurons (output layer)
)(
  input wire clk, //clock
  input wire rst, //reset
  input wire en, //enable
  input wire [N_IN-1:0] spike_in, //input spikes

  //weights for input layer (l1), neuron k at [k*W_WIDTH +: W_WIDTH]
  input wire [3:0] waddr_l1,
  input wire [N_HID*W_WIDTH-1:0] wdata_l1,
  input wire wen_l1,

  // weights for hidden layer (l2), neuron k at [k*W_WIDTH +: W_WIDTH]
  input wire [3:0] waddr_l2,
  input wire [N_OUT*W_WIDTH-1:0] wdata_l2,
  input wire wen_l2,

  output wire [N_OUT-1:0] spike_out //Final output spikes from the output layer
);

  wire [N_HID-1:0] hid_spike; //spikes from hidden layer to output layer

  hidden_layer #(
    .PREV_LAYER_NEURONS(N_IN),
    .CURR_LAYER_NEURONS(N_HID),
    .W_WIDTH(W_WIDTH), 
    .V_WIDTH(V_WIDTH)
  ) l1 (
    .clk(clk), 
    .rst(rst), 
    .en(en),
    .waddr(waddr_l1),
    .wdata(wdata_l1), 
    .wen(wen_l1),
    .prev_layer_spike(spike_in),
    .curr_layer_spike(hid_spike)
  );

  hidden_layer #(
    .PREV_LAYER_NEURONS(N_HID),
    .CURR_LAYER_NEURONS(N_OUT),
    .W_WIDTH(W_WIDTH), 
    .V_WIDTH(V_WIDTH)
  ) l2 (
    .clk(clk), 
    .rst(rst), 
    .en(en),
    .waddr(waddr_l2),
    .wdata(wdata_l2), 
    .wen(wen_l2),
    .prev_layer_spike(hid_spike), //spikes from first hidden layer
    .curr_layer_spike(spike_out) //output layer spike outputs
  );
endmodule
