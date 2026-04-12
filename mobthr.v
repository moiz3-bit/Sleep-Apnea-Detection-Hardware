`timescale 1ns / 1ps


module mobthr(
    input clk, rst,
    input signed [15:0] linput3,
    input valid_in,              // Trigger sync hook natively
    output reg signed [12:0] diff3, dder3,
    output reg signed [19:0] div13, div23, div33,
    output reg signed [35:0] vardif3, variance3, varddif3, tbdivided3, tbdivided23,
    output reg signed [32:0] divide3, divide13,
    output reg signed [15:0] mobthr, irreg3, varnew3,
    output reg signed start
);

    wire signed [12:0] dif3, diif3;
    wire signed [23:0] m13, m23, m33;
    wire signed [25:0] n13, n23, n33;
    wire signed [70:0] n43; 
    wire signed [30:0] m43, m443;
    wire signed [32:0] new3;
    wire signed [19:0] sfb103, sffb103, sfffb103, sfb113, sffb113, sfffb113, sfb123, sffb123, sfffb123, sfb133, sffb133, sfffb133, sfb143, sffb143, sfffb143, sfb153, sffb153, sfffb153, sfb1513, sffb1513;
    wire signed [25:0] sfb1523;
    wire signed [25:0] sfffb1513;
    wire c13, c23, c33, c43, c53, c63;
    
    reg signed [29:0] acc3, acc13, acc23;
    wire signed [39:0] quotient3, quotient13;
    wire signed [15:0] root3, root13;
    wire result_valid3, result_valid13;
    wire result_sr1, result_sr2;

    reg [15:0] count;
    reg t_calc_done;
    reg t_div1, t_div2;
    reg t_sr1, t_sr2;

    reg signed [12:0] del1, del2;

    assign dif3  = linput3 - del1;
    assign diif3 = diff3 - del2;

    multiplier123_thr m01(diff3, diff3, n13, m13);   
    multiplier123_thr m02(linput3, linput3, n23, m23);   
    multiplier123_thr m03(diif3, diif3, n33, m33);

    assign sfb103 = acc3 >> 10;
    assign sffb103 = acc13 >> 10;
    assign sfffb103 = acc23 >> 10;

    assign sfb113 = div13 >> 1;
    assign sffb113 = div23 >> 1;
    assign sfffb113 = div33 >> 1;
    assign sfb123 = div13 >> 3;
    assign sffb123 = div23 >> 3;
    assign sfffb123 = div33 >> 3;
    assign sfb143 = div13 >> 4;
    assign sffb143 = div23 >> 4; 
    assign sfffb143 = div33 >> 4;

    project_ad12_thr ad13(sfb113, sfb123, sfb133, c13);
    project_ad12_thr ad23(sfb133, sfb143, sfb153, c23);
    assign sfb1513 = sfb153 << 1;
    assign sfb1523 = sfb1513 << 6;

    project_ad12_thr ad33(sffb113, sffb123, sffb133, c33);
    project_ad12_thr ad43(sffb133, sffb143, sffb153, c43);
    assign sffb1513 = sffb153 << 1;

    project_ad12_thr ad53(sfffb113, sfffb123, sfffb133, c53);
    project_ad12_thr ad63(sfffb133, sfffb143, sfffb153, c63);
    assign sfffb1513 = sfffb153 << 1;

    multiplier1234_thr m04(variance3, varddif3, n43, m43);
    assign m443 = n43 >> 12;

    assign new3 = quotient3 << 6;

    division_thr dv13(vardif3, variance3, quotient3, clk, rst, t_div1, result_valid3);
    division_thr dv23(tbdivided23, tbdivided3, quotient13, clk, rst, t_div2, result_valid13);
    
    sroot_thr sr13(divide3, root3, clk, rst, t_sr1, result_sr1);
    sroot_thr sr23(divide13, root13, clk, rst, t_sr2, result_sr2);

    always @(posedge clk) begin
        if (rst) begin
            acc3 <= 0; acc13 <= 0; acc23 <= 0;
            diff3 <= 0; dder3 <= 0;
            div13 <= 0; div23 <= 0; div33 <= 0;
            vardif3 <= 0; varddif3 <= 0; tbdivided3 <= 0; variance3 <= 0; tbdivided23 <= 0;
            divide3 <= 0; divide13 <= 0;
            mobthr <= 0; irreg3 <= 0; varnew3 <= 0;
            start <= 0; count <= 0; del1 <= 0; del2 <= 0;
            
            t_calc_done <= 0; t_div1 <= 0; t_div2 <= 0; t_sr1 <= 0; t_sr2 <= 0;
        end else begin
            t_calc_done <= 0; t_div1 <= 0; t_div2 <= 0; t_sr1 <= 0; t_sr2 <= 0;

            if (valid_in) begin
                del1 <= linput3;
                del2 <= diff3;
                
                diff3 <= dif3;
                dder3 <= diif3;

                if (count < 750) begin
                    acc3 <= acc3 + m13;
                    acc13 <= acc13 + m23;
                    acc23 <= acc23 + m33;
                    count <= count + 1;
                end else begin
                    count <= 0;
                    t_calc_done <= 1; // triggers next stage math
                end
            end

            // Cascade Waterfall Sequence
            if (t_calc_done) begin
                div13 <= sfb103;
                div23 <= sffb103;
                div33 <= sfffb103;
                vardif3 <= sfb1513;
                variance3 <= sffb1513;
                varddif3 <= sfffb1513;
                varnew3 <= sffb1513;
                
                divide13 <= m443;
                
                t_div1 <= 1; // triggers division dv13
            end

            if (result_valid3) begin
                divide3 <= new3;
                t_sr1 <= 1; // triggers root1
                t_sr2 <= 1; // triggers root2
            end

            if (result_sr1 && result_sr2) begin
                mobthr <= root3;
                tbdivided3 <= root13;
                tbdivided23 <= sfb1523;
                t_div2 <= 1; // triggers last division
            end

            if (result_valid13) begin
                irreg3 <= quotient13;
                start <= 1;
            end else begin
                start <= 0;
            end
        end
    end
endmodule

// Custom Decoupled Square Root
module sroot_thr(input [31:0] X, output reg [15:0] B1, input clk, rst, start_root, output reg result_valid11); 
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

module project_ad12_thr(input [19:0] A, input [19:0] B, output reg [19:0] SUM1, output reg CARRY1);
    always @(A or B) {CARRY1, SUM1} = A + B;
endmodule

module multiplier123_thr(input signed [12:0] A, input signed [12:0] B, output signed [25:0] result1, output signed [23:0] msb_result1);
    assign result1 = A * B;
    assign msb_result1 = result1[23:0]; 
endmodule

module multiplier1234_thr(input signed [35:0] A, input signed [35:0] B, output signed [71:0] result1, output signed [30:0] msb_result1);
    assign result1 = A * B;
    assign msb_result1 = result1[30:0]; 
endmodule

// Custom Decoupled Division
module division_thr #(parameter DIVIDEND=35, parameter DIVISOR=35,parameter qt=39,parameter FRACTIONAL=0)(
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
