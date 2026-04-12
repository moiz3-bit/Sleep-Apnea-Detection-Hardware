`timescale 1ns / 1ps
module aadnle3(
    input clk, rst,
    input signed [15:0] linput3,
    input valid_in,              //  Trigger sync hook
    output [12:0] absol3,
    output [20:0] divid3,
    output [15:0] aad33,
    output signed [26:0] tbsum3,
    output signed [15:0] nle3,
    output startad3
);
    feature_aad_nle #(
        .LEVEL(3),
        .FRAME_SIZE(750), 
        .TEO_DELAY_TAPS(10) // Matches the 10 dff units (df1->df1003) from legacy logic!
    ) core (
        .clk(clk), .rst(rst), .data_in(linput3), .valid_in(valid_in),
        .absol_diff(absol3), .divid(divid3), .aad_out(aad33),
        .tbsum(tbsum3), .nle_out(nle3), .start_pulse(startad3)
    );
endmodule
