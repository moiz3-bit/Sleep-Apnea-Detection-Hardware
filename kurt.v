`timescale 1ns / 1ps
module feature_kurtosis #(
    parameter integer FRAME_SIZE = 3000,
    parameter integer N_MULT = 3000,
    parameter integer SHIFT_VAL = 19
)(
    input clk, rst, valid_in,
    input signed [15:0] data_in,
    
    // Explicit legacy debug ports exported
    output reg signed [29:0] square,
    output reg signed [44:0] quad,
    output reg signed [37:0] squared,
    output reg signed [60:0] squareddd,
    output reg signed [35:0] squared1,
    output reg signed [49:0] quadrap,
    output reg signed [45:0] quadrap1,
    output reg signed [35:0] afmult,
    output reg signed [15:0] kurt_out,
    output reg startk
);

    wire signed [29:0] m1;
    wire signed [35:0] n1;
    wire signed [44:0] m2;
    wire signed [49:0] n2;
    wire signed [60:0] m4;
    wire signed [65:0] n4;
    wire signed [50:0] m5;
    wire signed [81:0] n5;

    reg [15:0] sample_cnt;
    reg signed [37:0] acc;   // x^2 accumulator
    reg signed [49:0] acc1;  // x^4 accumulator

    // Internal pipeline sequences
    reg trig_squareddd;
    reg trig_shift;
    reg trig_mult;
    reg trig_div;

    // Standard multipliers matching legacy bounds strictly mapping exactly
    multiplier11 k_m01(data_in[12:0], data_in[12:0], n1, m1);  
    multiplier12 k_m02(square, square, n2, m2);
    multiplier14 k_m04(squared, squared, n4, m4);
    multiplier16 k_m07(quadrap1, N_MULT, n5, m5);  // Evaluates Dynamic N_MULT Parameter identically!

    wire signed [39:0] quotient;
    wire result_valid;
    
    // Decoupled Safe Trigger-based Divider
    kurt_division k_div(
        .A(afmult), .B(squared1), .q(quotient),
        .clk(clk), .reset(rst),
        .start_div(trig_div), 
        .result_valid(result_valid)
    );

    always @(posedge clk) begin
        if (rst) begin
            square <= 0;
            quad <= 0;
            acc <= 0;
            acc1 <= 0;
            squared <= 0;
            quadrap <= 0;
            squareddd <= 0;
            squared1 <= 0;
            quadrap1 <= 0;
            afmult <= 0;
            kurt_out <= 0;
            startk <= 0;
            sample_cnt <= 0;
            
            trig_squareddd <= 0;
            trig_shift <= 0;
            trig_mult <= 0;
            trig_div <= 0;
        end else begin
            trig_div <= 0; 
            
            // Sequential Post Accumulation Logic Matrix Waterfall
            if (trig_squareddd) begin
                squareddd <= m4;
                trig_squareddd <= 0;
                trig_shift <= 1;
            end
            if (trig_shift) begin
                // Dynamic Shift bounds matching Level parameters universally
                quadrap1 <= quadrap >>> SHIFT_VAL;
                squared1 <= squareddd >>> SHIFT_VAL;
                trig_shift <= 0;
                trig_mult <= 1;
            end
            if (trig_mult) begin
                afmult <= m5;
                trig_mult <= 0;
                trig_div <= 1; // Pulses the decoupled Division engine explicitly correctly matched to stable hardware!
            end

            // Main Window accumulation logic mapped cleanly over Valid flag
            if (valid_in) begin
                square <= m1;
                quad <= m2;
                
                if (sample_cnt < FRAME_SIZE - 1) begin
                    acc <= acc + m1;
                    acc1 <= acc1 + m2;
                    sample_cnt <= sample_cnt + 1;
                end else begin
                    // Frame Boundary Detected natively! Commit aggregators automatically!
                    squared <= acc + m1;
                    quadrap <= acc1 + m2;
                    acc <= 0;
                    acc1 <= 0;
                    sample_cnt <= 0;
                    trig_squareddd <= 1;
                end
            end
            
            // Collect the hardware math quotient once result outputs high inherently from safe Divider
            if (result_valid) begin
                kurt_out <= quotient[15:0];
                startk <= 1;
            end else begin
                startk <= 0;
            end
        end
    end
endmodule

module multiplier11(
    input signed [12:0] A, input signed [12:0] B,
    output signed [35:0] result, output signed [29:0] msb_result
);
    assign result = A * B;
    assign msb_result = result[29:0]; 
endmodule

module multiplier12(
    input signed [29:0] A, input signed [29:0] B,
    output signed [49:0] result, output signed [44:0] msb_result
);
    assign result = A * B;
    assign msb_result = result[44:0]; 
endmodule

module multiplier14(
    input signed [37:0] A, input signed [37:0] B,
    output signed [73:0] result, output signed [64:0] msb_result
);
    assign result = A * B;
    assign msb_result = result[64:0]; 
endmodule

module multiplier16(
    input signed [45:0] A, input signed [45:0] B,
    output signed [81:0] result, output signed [50:0] msb_result
);
    assign result = A * B;
    assign msb_result = result[50:0]; 
endmodule

module kurt_division #(parameter DIVIDEND=35, parameter DIVISOR=35, parameter qt=39, parameter FRACTIONAL=0)(
    input [DIVIDEND:0] A, 
    input [DIVISOR:0] B,
    output reg [qt:0] q, 
    input clk, reset, start_div,
    output reg result_valid
); 
    reg [15:0] count; 
    reg [qt:0] q1; 
    reg [DIVIDEND*2+1:0] overall; 
    reg calculating;
    
    always @(posedge clk) begin 
        if (reset) begin  
            count <= 0; 
            result_valid <= 0; 
            calculating <= 0;
            q <= 0;
            q1 <= 0;
            overall <= 0;
        end else begin
            if (start_div) begin
                calculating <= 1;
                count <= 0;
                result_valid <= 0;
                q1 <= 0;
                overall <= {36'b0, A}; // Init accumulator structurally matching old arrays manually 
            end else if (calculating) begin 
                count <= count + 1; 
                
                if (count >= 0) begin  
                    reg [DIVIDEND*2+1:0] temp_ov;
                    temp_ov = overall << 1;
                    if (temp_ov[DIVIDEND*2+1:DIVIDEND+1] >= B) begin
                        temp_ov[DIVIDEND*2+1:DIVIDEND+1] = temp_ov[DIVIDEND*2+1:DIVIDEND+1] - B;
                        q1 <= (q1 << 1) | 1'b1;
                    end else begin
                        q1 <= (q1 << 1);
                    end
                    overall <= temp_ov;
                end 
                
                if (count == DIVIDEND + FRACTIONAL + 2) begin 
                    result_valid <= 1;
                    calculating <= 0;
                    q <= q1;
                end 
            end else begin
                result_valid <= 0;
            end
        end
    end 
endmodule


module kurt(
    input clk, rst,
    input [15:0] linput1,
    input valid_in,              // Trigger sync pin
    output signed [29:0] square1,
    output signed [44:0] quad1,
    output signed [37:0] squared1,
    output signed [60:0] squareddd1,
    output signed [35:0] squared11,
    output signed [49:0] quadrap1,
    output signed [45:0] quadrap11,
    output signed [35:0] afmult1,
    output signed [15:0] kurt1,
    output startk1
);
    feature_kurtosis #(
        .FRAME_SIZE(3002), // Strictly CD1 Length boundaries mapped manually
        .N_MULT(3000),     // N Parameter dynamically synthesized natively
        .SHIFT_VAL(19)     // Shift bits safely synthesized explicitly 
    ) core (
        .clk(clk), .rst(rst), .data_in(linput1), .valid_in(valid_in),
        .square(square1), .quad(quad1), .squared(squared1),
        .squareddd(squareddd1), .squared1(squared11), .quadrap(quadrap1),
        .quadrap1(quadrap11), .afmult(afmult1), .kurt_out(kurt1), .startk(startk1)
    );
endmodule