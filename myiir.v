`timescale 1ns / 1ps

module myiir(
    input clk,
    input rst,
    input valid_in,
    input signed [15:0] linput,
    output reg signed [15:0] myiir_out,
    output reg valid_out
);

    parameter signed [15:0] b01 = 16'd358;
    parameter signed [15:0] b11 = 16'd716;
    parameter signed [15:0] b21 = 16'd358;
    parameter signed [15:0] a11 = -16'd832; 
    parameter signed [15:0] a21 = -16'd340;   

    parameter signed [15:0] b02 = 16'd512;
    parameter signed [15:0] b12 = 16'd1018;
    parameter signed [15:0] b22 = 16'd512;
    parameter signed [15:0] a12 = -16'd918; 
    parameter signed [15:0] a22 = -16'd434;  

    wire signed [15:0] sos1_out;
    reg signed [15:0] sos1_out_reg;
    wire signed [15:0] sos2_out;

    always @(posedge clk) begin
        if (rst) begin
            myiir_out <= 16'd0;
            sos1_out_reg <= 16'd0;
            valid_out <= 0;
        end else begin
            myiir_out <= sos2_out;
            sos1_out_reg <= sos1_out;
            valid_out <= valid_in;
        end
    end

    Biquad_SOS #(
        .B0(b01), .B1(b11), .B2(b21),
        .A1(a11), .A2(a21),
        .SHIFT_B(4), .SHIFT_A(9)
    ) sos1 (
        .clk(clk), .rst(rst),
        .data_in(linput),
        .data_out(sos1_out)
    );

    Biquad_SOS #(
        .B0(b02), .B1(b12), .B2(b22),
        .A1(a12), .A2(a22),
        .SHIFT_B(9), .SHIFT_A(9)
    ) sos2 (
        .clk(clk), .rst(rst),
        .data_in(sos1_out_reg),
        .data_out(sos2_out)
    );

endmodule


module Biquad_SOS #(
    parameter signed [15:0] B0 = 0,
    parameter signed [15:0] B1 = 0,
    parameter signed [15:0] B2 = 0,
    parameter signed [15:0] A1 = 0,
    parameter signed [15:0] A2 = 0,
    parameter integer SHIFT_B = 9,
    parameter integer SHIFT_A = 9
)(
    input clk,
    input rst,
    input signed [15:0] data_in,
    output signed [15:0] data_out
);

    reg signed [15:0] x1, x2;
    reg signed [15:0] y1, y2;

    always @(posedge clk) begin
        if (rst) begin
            x1 <= 16'd0; x2 <= 16'd0;
            y1 <= 16'd0; y2 <= 16'd0;
        end else begin
            x1 <= data_in;  x2 <= x1;
            y1 <= data_out; y2 <= y1;
        end
    end

    wire signed [31:0] m_b0_raw = data_in * B0;
    wire signed [31:0] m_b1_raw = x1 * B1;
    wire signed [31:0] m_b2_raw = x2 * B2;
    wire signed [31:0] m_a1_raw = y1 * A1;
    wire signed [31:0] m_a2_raw = y2 * A2;

    wire signed [31:0] m_b0_s = m_b0_raw >>> SHIFT_B;
    wire signed [31:0] m_b1_s = m_b1_raw >>> SHIFT_B;
    wire signed [31:0] m_b2_s = m_b2_raw >>> SHIFT_B;
    wire signed [31:0] m_a1_s = m_a1_raw >>> SHIFT_A;
    wire signed [31:0] m_a2_s = m_a2_raw >>> SHIFT_A;

    wire signed [15:0] m_b0 = (m_b0_s > 32'sd32767) ? 16'sd32767 : (m_b0_s < -32'sd32768) ? -16'sd32768 : m_b0_s[15:0];
    wire signed [15:0] m_b1 = (m_b1_s > 32'sd32767) ? 16'sd32767 : (m_b1_s < -32'sd32768) ? -16'sd32768 : m_b1_s[15:0];
    wire signed [15:0] m_b2 = (m_b2_s > 32'sd32767) ? 16'sd32767 : (m_b2_s < -32'sd32768) ? -16'sd32768 : m_b2_s[15:0];
    wire signed [15:0] m_a1 = (m_a1_s > 32'sd32767) ? 16'sd32767 : (m_a1_s < -32'sd32768) ? -16'sd32768 : m_a1_s[15:0];
    wire signed [15:0] m_a2 = (m_a2_s > 32'sd32767) ? 16'sd32767 : (m_a2_s < -32'sd32768) ? -16'sd32768 : m_a2_s[15:0];

    wire signed [31:0] sum_raw = m_b0 + m_b1 + m_b2 + m_a1 + m_a2;
    assign data_out = (sum_raw > 32'sd32767) ? 16'sd32767 : (sum_raw < -32'sd32768) ? -16'sd32768 : sum_raw[15:0];

endmodule
