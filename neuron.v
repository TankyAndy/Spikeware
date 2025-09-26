`timescale 1ns/1ns
module neuron #(
    parameter PREV_LAYER_NEURONS = 9, //# of previous neurons
    parameter W_WIDTH = 16, //weight width
    parameter V_WIDTH = 32, //voltage width

    parameter [V_WIDTH-1:0] V_TH = 32'h00010000, //spiking threshhold voltage
    parameter [V_WIDTH-1:0] V_RST = 32'h00000000, //reset voltage

    parameter [V_WIDTH-1:0] BIAS = 32'sd0, //bias voltage added every timestep

    parameter EXP = 1 //Exponential leak shift amount (V >>> EXP)
)(
    input wire clk, //clock
    input wire rst, //reset
    input wire en, //enable
    input wire [3:0] waddr, // address for weight write
    input wire [W_WIDTH-1:0] wdata, //new weight value
    input wire wen, //write enable
    input wire [PREV_LAYER_NEURONS-1:0] spike_in, //input spike
    output reg spike_out //output spike
);

    reg signed [V_WIDTH-1:0] V; //membrane voltage
    reg signed [W_WIDTH-1:0] syn_w [0:PREV_LAYER_NEURONS-1]; //array of synaptic weights
    
    reg signed [V_WIDTH-1:0] V_leak; //leaked voltage
    reg signed [V_WIDTH-1:0] V_sum; //total voltage
    reg signed [V_WIDTH-1:0] V_next; //voltage to pass on
    wire spike_evt; //spiking when voltage threshold met

    //when write enabled, update weight at address
    always @(posedge clk) begin
        if (wen) begin
            syn_w[waddr] <= wdata;
        end
    end

    //input voltage accumulation
    reg signed [V_WIDTH-1:0] sum_in; //sum of all inputs in timestep
    integer i;
    always @* begin
        sum_in = BIAS; //bias and sign extend to V_WIDTH
        for (i=0; i<PREV_LAYER_NEURONS; i=i+1) //for each input neuron, if it spikes, add its weight
            if (spike_in[i])
                sum_in = sum_in + {{(V_WIDTH-W_WIDTH){syn_w[i][W_WIDTH-1]}}, syn_w[i]};
    end

    always @* begin
        V_leak = V - (V >>> EXP); //exponential leak
        V_sum  = V_leak + sum_in; //add accumulated voltage

        //If voltage > spiking threshold, reset to V_RST, otherwise, carry forward current voltage
        if (V_sum >= V_TH) begin
            V_next = V_RST;
        end else begin
            V_next = V_sum;
        end
    end
    assign spike_evt = (V_sum >= V_TH); //spike if current voltage > spiking threshold

    always @(posedge clk) begin //states
        if (rst) begin //reset neuron
            V <= V_RST; spike_out <= 1'b0;
        end else if (en) begin //update neuron voltage and spike status
            V <= V_next; spike_out <= spike_evt;
        end
    end
endmodule
