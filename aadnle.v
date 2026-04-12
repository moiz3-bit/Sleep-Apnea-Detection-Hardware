`timescale 1ns / 1ps

module feature_aad_nle #(
    parameter integer LEVEL = 1,
    parameter integer FRAME_SIZE = 3000,
    parameter integer TEO_DELAY_TAPS = 3
)(
    input clk, rst, valid_in,
    input signed [15:0] data_in,
    
    output reg [12:0] absol_diff,
    output reg [20:0] divid,
    output reg [15:0] aad_out,
    output reg signed [26:0] tbsum,
    output reg signed [15:0] nle_out,
    output reg start_pulse
);

    reg [15:0] sample_cnt;
    
    // Max required mathematically is 10 for CA3/CD3
    reg signed [12:0] delay_line [0:11]; 
    integer i;

    wire signed [12:0] din_trunc = data_in[12:0];

    // Mathematical TEO multipliers and differences
    wire signed [23:0] X_squared;
    wire signed [25:0] n1;
    // Multiplier for X^2
    multiplier125_aad m_sq(din_trunc, din_trunc, n1, X_squared);
    
    // Tap lookup natively matched parametrically 
    wire signed [12:0] tap_val = delay_line[TEO_DELAY_TAPS-1];
    
    wire signed [23:0] cross_mult;
    wire signed [25:0] n2;
    multiplier125_aad m_cross(din_trunc, tap_val, n2, cross_mult);
    
    // Differential TEO
    reg signed [23:0] X_sq_delayed; // Delays X_squared to match tap boundaries structurally internally if needed.
    
    wire signed [23:0] diff_teo = X_sq_delayed - cross_mult;

    // AAD Mathematics 
    wire signed [12:0] x_n_minus_1 = delay_line[0];
    wire signed [12:0] diff_aad = din_trunc - x_n_minus_1;
    wire [12:0] abs_aad = (diff_aad[12]) ? (~diff_aad + 1) : diff_aad;

    // Accumulators
    reg [32:0] acc_aad;
    reg signed [32:0] acc_teo;

    // Output Triggers
    reg trigger_shift;
    
    // AAD Custom Scalers
    wire signed [20:0] sb10 = acc_aad >> 10;
    
    wire signed [20:0] l1_p1 = divid >> 2;
    wire signed [20:0] l1_p2 = divid >> 4;
    wire signed [20:0] l1_p3 = divid >> 5;
    wire signed [20:0] l1_aad = l1_p1 + l1_p2 + l1_p3;
    
    wire signed [20:0] l3_p1 = divid >> 1;
    wire signed [20:0] l3_p2 = divid >> 3;
    wire signed [20:0] l3_p3 = divid >> 4;
    wire signed [20:0] l3_aad = (l3_p1 + l3_p2 + l3_p3) << 1;

    wire signed [15:0] shifted_teo = acc_teo >> 16; 

    always @(posedge clk) begin
        if (rst) begin
            for(i=0; i<12; i=i+1) delay_line[i] <= 0;
            sample_cnt <= 0;
            acc_aad <= 0;
            acc_teo <= 0;
            X_sq_delayed <= 0;
            
            absol_diff <= 0;
            divid <= 0;
            aad_out <= 0;
            tbsum <= 0;
            nle_out <= 0;
            start_pulse <= 0;
            trigger_shift <= 0;
            
        end else begin
            
            if (trigger_shift) begin
                divid <= sb10;
                nle_out <= shifted_teo;
                if (LEVEL == 1)      aad_out <= l1_aad[15:0];
                else if (LEVEL == 3) aad_out <= l3_aad[15:0];
                
                start_pulse <= 1;
                trigger_shift <= 0;
            end else begin
                start_pulse <= 0;
            end
            
            if (valid_in) begin
                delay_line[0] <= din_trunc;
                for(i=1; i<12; i=i+1) delay_line[i] <= delay_line[i-1];
                X_sq_delayed <= X_squared;
                
                // Export internals natively
                absol_diff <= abs_aad;
                tbsum <= diff_teo;
                
                if (sample_cnt < FRAME_SIZE - 1) begin
                    acc_aad <= acc_aad + abs_aad;
                    acc_teo <= acc_teo + diff_teo;
                    sample_cnt <= sample_cnt + 1;
                end else begin
                    // Final frame aggregation
                    acc_aad <= acc_aad + abs_aad;
                    acc_teo <= acc_teo + diff_teo;
                    sample_cnt <= 0;
                    trigger_shift <= 1; 
                end
            end
            
            if (trigger_shift) begin
                acc_aad <= 0;
                acc_teo <= 0;
            end
        end
    end
endmodule

module multiplier125_aad(
    input signed [12:0] A,
    input signed [12:0] B,
    output signed [25:0] result,
    output signed [23:0] msb_result
);
    assign result = A * B;
    assign msb_result = result[23:0]; 
endmodule


module aadnle(
    input clk, rst,
    input signed [15:0] linput,
    input valid_in,              //  Trigger sync hook natively
    output [12:0] absol,
    output [20:0] divid,
    output [15:0] aad,
    output signed [26:0] tbsum,
    output signed [15:0] nle,
    output startad3
);
    feature_aad_nle #(
        .LEVEL(1),
        .FRAME_SIZE(3002), 
        .TEO_DELAY_TAPS(3) 
    ) core (
        .clk(clk), .rst(rst), .data_in(linput), .valid_in(valid_in),
        .absol_diff(absol), .divid(divid), .aad_out(aad),
        .tbsum(tbsum), .nle_out(nle), .start_pulse(startad3)
    );
endmodule
