`timescale 1ns / 1ps

module moba3(
    input clk, rst,
    input signed [15:0] linput3,
    input valid_in,              // Trigger sync hook natively
    output [12:0] absol3,
    output [20:0] divid3,
    output [15:0] aad33,
    output signed [26:0] tbsum3,
    output signed [15:0] mobil,  // Approximates Mobility via NLE
    output starta3
);
    feature_aad_nle #(
        .LEVEL(3),
        .FRAME_SIZE(750), 
        .TEO_DELAY_TAPS(10) 
    ) core (
        .clk(clk), .rst(rst), .data_in(linput3), .valid_in(valid_in),
        .absol_diff(absol3), .divid(divid3), .aad_out(aad33),
        .tbsum(tbsum3), .nle_out(mobil), .start_pulse(starta3)
    );
endmodule
