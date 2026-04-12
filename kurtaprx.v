`timescale 1ns / 1ps


module kurtaprx(
    input clk, rst,
    input [15:0] linput23,
    input valid_in,              // NEW: Trigger sync pin safely pipelined explicitly
    output signed [29:0] square3,
    output signed [44:0] quad3,
    output signed [37:0] squared3,
    output signed [60:0] squareddd3,
    output signed [35:0] squared13,
    output signed [49:0] quadrap3,
    output signed [45:0] quadrap13,
    output signed [35:0] afmult3,
    output signed [15:0] kurtaprx23,
    output starta3
);
    feature_kurtosis #(
        .FRAME_SIZE(750),  // Synthesizes the exact 750 CA3 sequence length explicitly matched internally manually natively 
        .N_MULT(750),      // Maps strict parameters natively safely manually!
        .SHIFT_VAL(29)     // Uses the extended shift parameters properly explicitly identically!
    ) core (
        .clk(clk), .rst(rst), .data_in(linput23), .valid_in(valid_in),
        .square(square3), .quad(quad3), .squared(squared3),
        .squareddd(squareddd3), .squared1(squared13), .quadrap(quadrap3),
        .quadrap1(quadrap13), .afmult(afmult3), .kurt_out(kurtaprx23), .startk(starta3)
    );

endmodule
