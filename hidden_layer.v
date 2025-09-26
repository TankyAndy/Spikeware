`timescale 1ns/1ns

module hidden_layer #(
    parameter  PREV_LAYER_NEURONS = 9, //# of previous neurons
    parameter  CURR_LAYER_NEURONS = 6, //# of current layer neurons
    parameter  W_WIDTH       = 16, //weight width
    parameter  V_WIDTH       = 32, //voltage width
    // pass-through neuron params (tune as needed)
    parameter [V_WIDTH-1:0] V_TH    = 32'h0000_0333, // ≈ 0.20 * 4096
    parameter [V_WIDTH-1:0] V_RST  = 32'h0000_0000, //reset voltage
    parameter [V_WIDTH-1:0] BIAS    = 32'sd0, //bias voltage added every timestep
    parameter  EXP = 1 //Exponential leak shift amount
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         en,
    input  wire [3:0]                   waddr,  //weight address
    input  wire [CURR_LAYER_NEURONS*W_WIDTH-1:0] wdata, //weight data (all weights stored side by side).
    //bits [W_WIDTH-1:0] go to neuron 0, [2*W_WIDTH-1:W_WIDTH] to neuron 1...
    
    input  wire                         wen, //write enable
    input  wire [PREV_LAYER_NEURONS-1:0] prev_layer_spike, //input spike
    output wire [CURR_LAYER_NEURONS-1:0] curr_layer_spike //current spike
);

    genvar k; //generate loop variable
    generate //create CURR_LAYER_NEURON neuron instances
        for (k = 0; k < CURR_LAYER_NEURONS; k = k + 1) begin : G_NEUR
            neuron #(
                .PREV_LAYER_NEURONS(PREV_LAYER_NEURONS),
                .W_WIDTH(W_WIDTH),
                .V_WIDTH(V_WIDTH),
                .V_TH(V_TH), 
                .V_RST(V_RST),
                .BIAS(BIAS),
                .EXP(EXP)
            ) u_neuron (
                .clk   (clk),
                .rst   (rst),
                .en    (en),
                .waddr (waddr),
                .wdata (wdata[k*W_WIDTH +: W_WIDTH]), //select weight of specific neuron in wdata
                .wen   (wen),
                .spike_in (prev_layer_spike),
                .spike_out(curr_layer_spike[k]) //select spike of specific neuron
            );
        end
    endgenerate
endmodule
