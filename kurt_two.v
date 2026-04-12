`timescale 1ns / 1ps
module kurt_two(
    input clk, rst,
    input [15:0] linput2,
    input valid_in,              // Trigger sync pin safely pipelined explicitly
    output signed [29:0] square,
    output signed [44:0] quad,
    output signed [37:0] squared,
    output signed [60:0] squareddd,
    output signed [35:0] squared1,
    output signed [49:0] quadrap,
    output signed [45:0] quadrap1,
    output signed [35:0] afmult,
    output signed [15:0] kurt2,
    output startk3
);
    feature_kurtosis #(
        .FRAME_SIZE(750),  // Synthesizes the exact 750 CD3 sequence length
        .N_MULT(750),      // Maps strict parameters natively
        .SHIFT_VAL(29)     // Uses the extended shift parameters properly explicitly identically to original files
    ) core (
        .clk(clk), .rst(rst), .data_in(linput2), .valid_in(valid_in),
        .square(square), .quad(quad), .squared(squared),
        .squareddd(squareddd), .squared1(squared1), .quadrap(quadrap),
        .quadrap1(quadrap1), .afmult(afmult), .kurt_out(kurt2), .startk(startk3)
    );

endmodule
