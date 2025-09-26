// top.v — tiny 2-class LED display
`timescale 1ns/1ns
`default_nettype none

module spikeware (
    input  wire       CLOCK_50,
    output wire [9:0] LEDR
);
  // clock & POR
  wire clk = CLOCK_50;
  reg [15:0] por = 16'h0000;

  always @(posedge clk) begin
    por <= {por[14:0], 1'b1};
  end

  wire rst = ~por[15];

  // one-shot start
  reg started = 1'b0, start_pulse = 1'b0;
  always @(posedge clk) begin
    if (rst) begin 
      started <= 1'b0; 
      start_pulse <= 1'b0; 
    end else if (!started) begin 
      start_pulse <= 1'b1; 
      started <= 1'b1; 
    end else begin 
      start_pulse <= 1'b0;
    end
  end

  // SNN core (2 outputs -> pred_bit)
  wire done;
  wire pred_bit;

  snn #(
    .W_WIDTH(16), .V_WIDTH(32), .T(32),
    .W1_FILE("w1.hex"),
    .W2_FILE("w2.hex"),
    .IN_FILE("input_spikes.hex")
  ) u_snn (
    .clk  (clk),
    .rst  (rst),
    .start(start_pulse),
    .done (done),
    .pred_bit(pred_bit)
  );

  // ---- LED decode (pick ONE style) ----
  // (A) Minimal: show just pred_bit on LEDR[0]
  assign LEDR[9]   = done;
  assign LEDR[0]   = done ? pred_bit : 1'b0;
  assign LEDR[8:1] = 8'b0;

  // // (B) One-hot 2-class on LEDR[3:0] (uncomment to use)
  // wire [3:0] class_onehot = pred_bit ? 4'b0010 : 4'b0001;
  // assign LEDR[3:0] = done ? class_onehot : 4'b0000;
  // assign LEDR[9]   = done;
  // assign LEDR[8:4] = 5'b0;

endmodule

`default_nettype wire
