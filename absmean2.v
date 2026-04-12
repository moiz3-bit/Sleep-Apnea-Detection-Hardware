`timescale 1ns / 1ps
module absmean2(
    input clk,                   
    input rst,                   
    input signed [15:0] linput,  
    input valid_in,              //  Streaming sync hook
    output signed [15:0] absolute, 
    output signed [19:0] sum, 
    output signed [19:0] div, 
    output signed [15:0] mean,
    output start_m2              
);

    feature_absmean #(
        .LEVEL(2),
        .FRAME_SIZE(1500) // Synthesizes the exact 1500 L2 sequence length
    ) core (
        .clk(clk),
        .rst(rst),
        .data_in(linput),
        .valid_in(valid_in),
        .absolute_val(absolute),
        .sum(sum),
        .div(div),
        .mean_out(mean),
        .valid_out(start_m2)
    );

endmodule