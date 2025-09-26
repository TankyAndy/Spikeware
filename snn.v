`timescale 1ns/1ns
module snn #(
  parameter W_WIDTH = 16, //weight width
  parameter V_WIDTH = 32, //voltage width
  parameter T = 32, //total number of timesteps
  parameter W1_FILE = "w1.hex", //ROM file for weights of first layer
  parameter W2_FILE = "w2.hex", //ROM file for weights of second layer
  parameter IN_FILE = "input_spikes.hex" //ROM file for input spikes
)(
  input wire clk, //clock
  input wire rst, //sychronous reset
  input wire start, //start signal from top.v
  output reg done, //inference complete signal
  output wire pred_bit //final predicted class (0 or 1)
);

  parameter N_IN  = 9; //# input neuonrs (input layer)
  parameter N_HID = 6; //#number of neurons per hidden layer
  parameter N_OUT = 2; //# output neurons (output layer)

  reg [2:0] st; //current state
  reg [3:0] a1; //row counter for ROM weight 1
  reg [2:0] a2; //row counter for ROM weight 2
  reg [4:0] tt; //time step counter

  //ROM
  wire [N_HID*W_WIDTH-1:0] w1_row; //all weights of first layer
  wire [N_OUT*W_WIDTH-1:0] w2_row; //all weights of second layer
  wire [N_IN-1:0] in_row; //all input spikes

  //FSM
  parameter IDLE=0; //wait for start
  parameter INIT1=1; //fetch row for first layer weights
  parameter INIT1_W=2; //write row into hidden layer neurons
  parameter INIT2=3; //fetch row for second layer weights
  parameter INIT2_W=4; //write row into output layer neurons
  parameter RUN=5; //run network across timesteps
  parameter DONE=6; //inference done

  //ROM for first layer (input to hidden layer) weights
  rom #(
    .DEPTH(9), //9 rows for 9 neurons
    .WIDTH(N_HID*W_WIDTH), //all 6 packed weights for of 9 input neurons
    .A_WIDTH(4), //address width
    .FILE(W1_FILE) //hex file with weights of first layer (w1.hex)
  ) u_w1 (
    .clk(clk), 
    .en(1'b1), 
    .addr(a1), //which neuron weights to read
    .dout(w1_row) //outputs the 6 weights for input neuron a1
  );

  //ROM for second layer (hidden to output layer) weights
  rom #(
    .DEPTH(6), //6 rows for 6 hidden layer neurons
    .WIDTH(N_OUT*W_WIDTH), //all 2 packed weights for each hidden neuron
    .A_WIDTH(3),
    .FILE(W2_FILE) //hex file with weights of second layer (w2.hex)
  ) u_w2 (
    .clk(clk), 
    .en(1'b1), 
    .addr(a2), 
    .dout(w2_row) //outputs the 2 weights for hidden neuron a2
  );

  //ROM for input spikes
  rom #(
    .DEPTH(T), //T (# timesteps) rows
    .WIDTH(N_IN), //9 inputs per row
    .A_WIDTH(5),
    .FILE(IN_FILE) //hex file for input spikes (input_spikes.hex)
  ) u_in (
    .clk(clk), 
    .en(1'b1), 
    .addr(tt), //incremement timesteps
    .dout(in_row) //output spike pattern for timestep tt
  );

  //Main SNN
  wire [N_OUT-1:0] out_spike; //spikes from output layer
  reg en_SNN; //enable for SNN
  reg  [3:0] waddr_l1; //weight addresses layer 1
  reg  [3:0] waddr_l2; //weight addresses layer 2
  reg wen_l1; //write enable for layer 1
  reg wen_l2; //write enable for layer 2
  wire [5:0] c0; //spike count for first output neuron (0)
  wire [5:0] c1; //spike count for second output neuron (1)

  snn_two_layer #(
    .W_WIDTH(W_WIDTH), 
    .V_WIDTH(V_WIDTH), 
    .N_IN(N_IN), 
    .N_HID(N_HID), 
    .N_OUT(N_OUT)
  )

  net (
    .clk(clk), 
    .rst(rst), 
    .en(en_SNN),
    .spike_in(in_row), //input spikes from ROM
    .waddr_l1(waddr_l1), 
    .wdata_l1(w1_row), 
    .wen_l1(wen_l1),
    .waddr_l2(waddr_l2), 
    .wdata_l2(w2_row), 
    .wen_l2(wen_l2),
    .spike_out(out_spike) //output spikes
  );

  counter #(6) u_c0 ( //counter for output neuron 0
    .clk(clk), 
    .rst(rst), 
    .en(st==RUN), //enable counting only when FSM is in RUN state
    .sig(out_spike[0]), //spikes from output neuron 0
    .q(c0) //# spikes neuron 0 produced
  );

  counter #(6) u_c1 ( //counter for output neuron 1
    .clk(clk), 
    .rst(rst), 
    .en(st==RUN), 
    .sig(out_spike[1]), //spikes from output neuron 1
    .q(c1) //# spikes neuron 1  produced
  );

  argmax #(6) u_am ( //argmas to determine winning neuron/predicted class
    .c0(c0), //# spikes from neuron 0
    .c1(c1), //# spikes from neuron 1
    .pred_bit(pred_bit) //prediced class: 0 or 1
  );


  always @(posedge clk) begin
    if (rst) begin //if rst, reset counters and go to idle
      st <= IDLE;
      a1 <= 0; //counter to read rom for layer 1
      a2 <= 0; //counter to read rom for layer 2
      tt <= 0; //timestep counter
      wen_l1 <= 1'b0; //write enable layer 1
      wen_l2 <= 1'b0; //write enable layer 2
      en_SNN <= 1'b0; //main SNN
      done <= 1'b0; //done flag
      waddr_l1 <= 0; //set weight address layer 1
      waddr_l2 <= 0; //set weight address layer 2
    end else begin
      //Default values every cycle
      wen_l1 <= 1'b0;
      wen_l2 <= 1'b0;
      en_SNN <= 1'b0;
      done <= 1'b0;
      waddr_l1 <= a1;   // keep weight addr in sync with counters
      waddr_l2 <= a2;

      case (st)
        IDLE: begin //wait for start signal
          a1 <= 0; 
          a2 <= 0; 
          tt <= 0;
          if (start) begin
            st <= INIT1;
          end
        end

        INIT1: begin //get row from first layer weight ROM
          st <= INIT1_W;
        end

        INIT1_W: begin
          wen_l1 <= 1'b1;    //write weights for first layer
          if (a1 == 4'd8) begin //loop until all 9 input neurons processed
            a1 <= 0;
            st <= INIT2;
          end else begin
            a1 <= a1 + 1'b1;
            st <= INIT1;
          end
        end

        INIT2: begin //get row from second layer weight ROM
          st <= INIT2_W;
        end

        INIT2_W: begin
          wen_l2 <= 1'b1; //write weights for layer 2
          if (a2 == 3'd5) begin //loop until all 6 hidden neurons processed
            a2 <= 0;
            st <= RUN;
          end else begin
            a2 <= a2 + 1'b1;
            st <= INIT2;
          end
        end

        RUN: begin
          en_SNN <= 1'b1; //enable SNN
          if (tt == (T-1)) begin //stop after T timesteps
            st <= DONE; //Inference complete
          end else begin
            tt <= tt + 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1; // inference complete signal on
        end

        default: st <= IDLE;

      endcase
    end
  end

endmodule
