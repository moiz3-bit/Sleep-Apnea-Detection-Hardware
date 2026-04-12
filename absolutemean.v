`timescale 1ns / 1ps

module feature_absmean #(
    parameter integer LEVEL = 1,
    parameter integer FRAME_SIZE = 3000
)(
    input clk,
    input rst,
    input signed [15:0] data_in,
    input valid_in,
    
    output reg signed [15:0] absolute_val,
    output reg signed [19:0] sum,
    output reg signed [19:0] div,
    output reg signed [15:0] mean_out,
    output reg valid_out 
);

    reg [15:0] sample_cnt;
    reg signed [19:0] acc;
    
    reg trigger_div;
    reg trigger_mean;
    reg trigger_valid;

    wire signed [15:0] abs_val = (data_in[15]) ? (~data_in + 1) : data_in;
    
    wire signed [19:0] sb10 = acc >>> 10;
    
    // Legacy custom shifts mapped strictly per specification to retain math bias
    wire signed [19:0] l1_sb11 = div >>> 2;
    wire signed [19:0] l1_sb12 = div >>> 3;
    wire signed [19:0] l1_mean = l1_sb11 + l1_sb12;
    
    wire signed [19:0] l2_sb11 = div >>> 1;
    wire signed [19:0] l2_sb12 = div >>> 3;
    wire signed [19:0] l2_sb14 = div >>> 4;
    wire signed [19:0] l2_mean = l2_sb11 + l2_sb12 + l2_sb14;
    
    wire signed [19:0] l3_mean = (l2_sb11 + l2_sb12 + l2_sb14) <<< 1;

    always @(posedge clk) begin
        if (rst) begin
            absolute_val <= 0;
            acc <= 0;
            sample_cnt <= 0;
            sum <= 0;
            div <= 0;
            mean_out <= 0;
            valid_out <= 0;
            
            trigger_div <= 0;
            trigger_mean <= 0;
            trigger_valid <= 0;
        end else begin
            // Shift pipeline
            trigger_mean <= trigger_div;
            trigger_valid <= trigger_mean;
            
            if (valid_in) begin
                absolute_val <= abs_val;
                
                if (sample_cnt < FRAME_SIZE - 1) begin
                    acc <= acc + abs_val;
                    sample_cnt <= sample_cnt + 1;
                    trigger_div <= 1'b0;
                end else begin
                    // Final sample of the frame!
                    acc <= acc + abs_val;
                    sample_cnt <= 0;     // Automatically restart accumulation!
                    trigger_div <= 1'b1; // Trigger division on next clk
                end
            end else begin
                trigger_div <= 1'b0; // clear trigger if not valid
            end
            
            if (trigger_div) begin
                sum <= acc;
                div <= sb10;
                acc <= 0; // reset accumulator for next frame officially
            end
            
            if (trigger_mean) begin
                if (LEVEL == 1)      mean_out <= l1_mean[15:0];
                else if (LEVEL == 2) mean_out <= l2_mean[15:0];
                else if (LEVEL == 3) mean_out <= l3_mean[15:0];
            end
            
            if (trigger_valid) begin
                valid_out <= 1'b1; // Pulse valid! Mean is ready structurally.
            end else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule

module absolutemean(
    input clk,                   
    input rst,                   
    input signed [15:0] linput,  
    input valid_in,              // Streaming sync hook
    output signed [15:0] absolute, 
    output signed [19:0] sum, 
    output signed [19:0] div, 
    output signed [15:0] mean,
    output start_m1              // Matches valid_out trigger
);

    feature_absmean #(
        .LEVEL(1),
        .FRAME_SIZE(3002) // Original negedge window exactly (3001-2)
    ) core (
        .clk(clk),
        .rst(rst),
        .data_in(linput),
        .valid_in(valid_in),
        .absolute_val(absolute),
        .sum(sum),
        .div(div),
        .mean_out(mean),
        .valid_out(start_m1)
    );

endmodule
