`timescale 1ns / 1ps


module aadnle_a3(
    input clk, rst,
    input signed [15:0] linput3,
    input valid_in,              // NEW: Trigger sync hook natively
    output [12:0] absol3,
    output [20:0] divid3,
    output [15:0] aad33,
    output signed [26:0] tbsum3,
    output signed [15:0] nle3,
    output starta3
);
    feature_aad_nle #(
        .LEVEL(3),
        .FRAME_SIZE(750), 
        .TEO_DELAY_TAPS(10) // Strictly mimics original 10-cycle distance mathematics
    ) core (
        .clk(clk), .rst(rst), .data_in(linput3), .valid_in(valid_in),
        .absol_diff(absol3), .divid(divid3), .aad_out(aad33),
        .tbsum(tbsum3), .nle_out(nle3), .start_pulse(starta3)
    );
endmodule
