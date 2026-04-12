`timescale 1ns / 1ps

module mfactor(
    input clk, rst,
    input signed [15:0] linput,
    input valid_in,              //  Trigger sync hook natively
    output reg signed [12:0] diff1, dder1,
    output reg signed [19:0] div11, div21, div31,
    output reg signed [35:0] vardif1, variance1, varddif1, tbdivided1,
    output reg signed [32:0] divide1, divide11,
    output reg signed [15:0] mfactor, irreg1, varnew1,
    output reg signed start_mob
);

    wire signed [12:0] y_11, dif1, diff_11, diif1;
    wire signed [23:0] m11, m21, m31;
    wire signed [25:0] n11, n21, n31;
    wire signed [71:0] n41;
    wire signed [30:0] m41;
    wire signed [32:0] new1;
    wire signed [19:0] sfb101, sffb101, sfffb101, sfb111, sffb111, sfffb111, sfb121, sffb121, sfffb121, sfb131, sffb131, sfffb131, sfb141, sffb141, sfffb141, sfb151, sffb151, sfffb151;
    wire b11, b21, c11, c21, c31, c41, c51, c61;
    reg signed [29:0] acc1, acc11, acc21;
    
    wire signed [39:0] quotient1, quotient11;
    wire signed [15:0] root1, root11;
    wire result_valid1, result_valid2;
    wire result_sr1, result_sr2;

    reg [15:0] count;
    reg t_calc_done;
    reg t_div1, t_div2;
    reg t_sr1, t_sr2;

    reg signed [12:0] del1, del2;

    // Combinational delays for differential logic
    assign dif1  = linput - del1;
    assign diif1 = dif1 - del2;

    multiplier123_m m01(diff1, diff1, n11, m11);   
    multiplier123_m m02(linput, linput, n21, m21);   
    multiplier123_m m03(dder1, dder1, n31, m31);

    assign sfb101 = acc1 >> 10;
    assign sffb101 = acc11 >> 10;
    assign sfffb101 = acc21 >> 10;

    assign sfb111 = div11 >> 2;
    assign sffb111 = div21 >> 2;
    assign sfffb111 = div31 >> 2;
    assign sfb121 = div11 >> 4;
    assign sffb121 = div21 >> 4;
    assign sfffb121 = div31 >> 4;
    assign sfb141 = div11 >> 5;
    assign sffb141 = div21 >> 5; 
    assign sfffb141 = div31 >> 5;

    project_ad12_m ad11(sfb111, sfb121, sfb131, c11);
    project_ad12_m ad21(sfb131, sfb141, sfb151, c21);

    project_ad12_m ad31(sffb111, sffb121, sffb131, c31);
    project_ad12_m ad41(sffb131, sffb141, sffb151, c41);

    project_ad12_m ad51(sfffb111, sfffb121, sfffb131, c51);
    project_ad12_m ad61(sfffb131, sfffb141, sfffb151, c61);

    multiplier1234_m m04(variance1, varddif1, n41, m41);

    assign new1 = quotient1 << 6;

    // Decoupled Custom State Engines!
    division_mf dv11(vardif1, variance1, quotient1, clk, rst, t_div1, result_valid1);
    division_mf dv21(vardif1, tbdivided1, quotient11, clk, rst, t_div2, result_valid2);
    
    sroot_mf sr11(divide1, root1, clk, rst, t_sr1, result_sr1);
    sroot_mf sr21(divide11, root11, clk, rst, t_sr2, result_sr2);

    always @(posedge clk) begin
        if (rst) begin
            acc1 <= 0; acc11 <= 0; acc21 <= 0;
            diff1 <= 0; dder1 <= 0;
            div11 <= 0; div21 <= 0; div31 <= 0;
            vardif1 <= 0; varddif1 <= 0; tbdivided1 <= 0; variance1 <= 0;
            divide1 <= 0; divide11 <= 0;
            mfactor <= 0; irreg1 <= 0; varnew1 <= 0;
            start_mob <= 0; count <= 0; del1 <= 0; del2 <= 0;
            
            t_calc_done <= 0; t_div1 <= 0; t_div2 <= 0; t_sr1 <= 0; t_sr2 <= 0;
        end else begin
            t_calc_done <= 0; t_div1 <= 0; t_div2 <= 0; t_sr1 <= 0; t_sr2 <= 0;

            if (valid_in) begin
                del1 <= linput;
                del2 <= diff1;
                
                diff1 <= dif1;
                dder1 <= diif1;

                if (count < 3000) begin
                    acc1 <= acc1 + m11;
                    acc11 <= acc11 + m21;
                    acc21 <= acc21 + m31;
                    count <= count + 1;
                end else begin
                    count <= 0;
                    t_calc_done <= 1; // triggers next stage math
                end
            end

            // Cascade Waterfall Sequence
            if (t_calc_done) begin
                div11 <= sfb101;
                div21 <= sffb101;
                div31 <= sfffb101;
                vardif1 <= sfb151;
                variance1 <= sffb151;
                varddif1 <= sfffb151;
                varnew1 <= sffb151;
                
                divide11 <= m41;
                
                t_div1 <= 1; // triggers division dv11
            end

            if (result_valid1) begin
                divide1 <= new1;
                t_sr1 <= 1; // triggers root1
                t_sr2 <= 1; // triggers root2
            end

            if (result_sr1 && result_sr2) begin
                mfactor <= root1;
                tbdivided1 <= root11;
                t_div2 <= 1; // triggers last division
            end

            if (result_valid2) begin
                irreg1 <= quotient11;
                start_mob <= 1;
            end else begin
                start_mob <= 0;
            end
        end
    end
endmodule

// Custom Square Root
module sroot_mf(input [31:0] X, output reg [15:0] B1, input clk, rst, start_root, output reg result_valid11); 
    reg [31:0] accum11; 
    reg signed [31:0] t11=0; 
    reg [15:0] q11; 
    reg signed [63:0] overall11; 
    reg [15:0] count21; 
    reg calculating;
    
    always @(posedge clk) begin 
        if(rst) begin 
            count21<=0; result_valid11<=0; calculating<=0;
        end else begin 
            if (start_root) begin
                calculating <= 1;
                count21 <= 0;
                result_valid11 <= 0;
            end

            if (calculating) begin 
                count21 <= count21 + 1;  
                if(count21 == 0) begin 
                    accum11=0; 
                    q11=0; 
                    overall11={accum11,X}; 
                end else begin 
                    overall11=overall11<<2; 
                    t11=overall11[63:32]-{2'b00,q11,2'b01}; 
                    q11=q11<<1; 
                    if(t11>=0) begin 
                        overall11[63:32]=t11; 
                        q11[0]=1; 
                    end 
                end 
                if(count21 == 17) begin 
                    result_valid11 <= 1; 
                    B1 <= q11; 
                    calculating <= 0;
                end 
            end else begin
                result_valid11 <= 0;
            end
        end 
    end 
endmodule

module project_ad12_m(input [19:0] A, input [19:0] B, output reg [19:0] SUM1, output reg CARRY1);
    always @(A or B) {CARRY1, SUM1} = A + B;
endmodule

module multiplier123_m(input signed [12:0] A, input signed [12:0] B, output signed [25:0] result1, output signed [23:0] msb_result1);
    assign result1 = A * B;
    assign msb_result1 = result1[23:0]; 
endmodule

module multiplier1234_m(input signed [35:0] A, input signed [35:0] B, output signed [71:0] result1, output signed [30:0] msb_result1);
    assign result1 = A * B;
    assign msb_result1 = result1[30:0]; 
endmodule

// Custom Decoupled Division
module division_mf #(parameter DIVIDEND=35, parameter DIVISOR=35,parameter qt=39,parameter FRACTIONAL=0)(
    input [DIVIDEND:0] A, input [DIVISOR:0] B, output reg [qt:0] q1, input clk, reset, start_div, output reg result_valid1
); 
    reg signed [DIVIDEND:0] accum1; 
    reg [15:0] count1; 
    reg signed [qt:0] q11=0; 
    reg [DIVIDEND:0] a11; 
    reg [DIVISOR:0] b11; 
    reg signed [DIVIDEND*2+1:0] overall1; 
    reg calculating;
    
    always @(posedge clk) begin 
        if(reset) begin  
            count1<=0; result_valid1<=0; calculating <= 0;
        end else begin 
            if (start_div) begin
                calculating <= 1;
                count1 <= 0;
                result_valid1 <= 0;
            end

            if (calculating) begin 
                count1 <= count1 + 1; 
                if(count1 == 0) begin 
                    a11=A; 
                    accum1=0; 
                    overall1={accum1,A}; 
                end else begin  
                    b11=B; 
                    overall1=overall1<<1; 
                    q11=q11<<1; 
                    if(overall1[DIVIDEND*2+1:DIVIDEND+1]>=b11) begin 
                        overall1[DIVIDEND*2+1:DIVIDEND+1]=overall1[DIVIDEND*2+1:DIVIDEND+1]-b11; 
                        q11[0]=1; 
                    end else begin 
                        q11[0]=0; 
                    end 
                end 
                
                if(count1 == DIVIDEND+FRACTIONAL+2) begin 
                    result_valid1 <= 1; 
                    q1 <= q11; 
                    calculating <= 0;
                end 
            end else begin
                result_valid1 <= 0;
            end
        end 
    end 
endmodule
