`timescale 1ns / 1ps

module hjorth(
    input clk, rst,
    input signed [15:0] linput3,
    input valid_in,              // Trigger sync hook natively
    output [12:0] absol3,
    output [20:0] divid3,
    output [15:0] hjorth,        // Calculates AAD
    output signed [26:0] tbsum3,
    output signed [15:0] irreg,  // Calculates NLE structural difference natively
    output startad3, startbram2, startac
);
    // Explicit trigger chains preserved
    assign startbram2 = startad3;
    assign startac = startad3;

    feature_aad_nle #(
        .LEVEL(3), // Because Hjorth leverages division shift mapping matched to L3!
        .FRAME_SIZE(750), 
        .TEO_DELAY_TAPS(10) // 10 cycle tap
    ) core (
        .clk(clk), .rst(rst), .data_in(linput3), .valid_in(valid_in),
        .absol_diff(absol3), .divid(divid3), .aad_out(hjorth),
        .tbsum(tbsum3), .nle_out(irreg), .start_pulse(startad3)
    );
endmodule
