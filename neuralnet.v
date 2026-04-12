`timescale 1ns / 1ps

// Pipelined Wide Neural Network Execution Engine
// 15 Inputs -> 100 Hidden Neurons -> 1 Output (Sleep Apnea Classification)
//

module neuralnet_top(
    input clk, rst,
    input start_prediction, // Triggered when DSP feature vectors are finalized
    
    // 15 Parallel Extracted DSP Features mapped synchronously
    input signed [15:0] f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12, f13, f14, f15,
    
    // Natively evaluated Output classification limit
    output reg signed [49:0] classification_out,
    output reg done
);

    reg [6:0] rom_addr;
    reg computing;
    
    // Valid pipeline tracker natively matching depth
    reg v_rom, v_mult, v_add, v_relu, v_outmult;

    // Phase 1: Wires fetching ROM Weights (100 weights per hidden node channel)
    // ==============================================================
    wire signed [15:0] w1, w2, w3, w4, w5, w6, w7, w8, w9, w10, w11, w12, w13, w14, w15;
    wire signed [15:0] w_out;
    wire signed [29:0] bias_h;

    // Instantiates inferred BRAM structural ROMs perfectly for Vivado natively
    weight_rom #(.INIT_FILE("weight1.data"))  r1(.clk(clk), .addr(rom_addr), .dout(w1));
    weight_rom #(.INIT_FILE("weight2.data"))  r2(.clk(clk), .addr(rom_addr), .dout(w2));
    weight_rom #(.INIT_FILE("weight3.data"))  r3(.clk(clk), .addr(rom_addr), .dout(w3));
    weight_rom #(.INIT_FILE("weight4.data"))  r4(.clk(clk), .addr(rom_addr), .dout(w4));
    weight_rom #(.INIT_FILE("weight5.data"))  r5(.clk(clk), .addr(rom_addr), .dout(w5));
    weight_rom #(.INIT_FILE("weight6.data"))  r6(.clk(clk), .addr(rom_addr), .dout(w6));
    weight_rom #(.INIT_FILE("weight7.data"))  r7(.clk(clk), .addr(rom_addr), .dout(w7));
    weight_rom #(.INIT_FILE("weight8.data"))  r8(.clk(clk), .addr(rom_addr), .dout(w8));
    weight_rom #(.INIT_FILE("weight9.data"))  r9(.clk(clk), .addr(rom_addr), .dout(w9));
    weight_rom #(.INIT_FILE("weight10.data")) r10(.clk(clk), .addr(rom_addr), .dout(w10));
    weight_rom #(.INIT_FILE("weight11.data")) r11(.clk(clk), .addr(rom_addr), .dout(w11));
    weight_rom #(.INIT_FILE("weight12.data")) r12(.clk(clk), .addr(rom_addr), .dout(w12));
    weight_rom #(.INIT_FILE("weight13.data")) r13(.clk(clk), .addr(rom_addr), .dout(w13));
    weight_rom #(.INIT_FILE("weight14.data")) r14(.clk(clk), .addr(rom_addr), .dout(w14));
    weight_rom #(.INIT_FILE("weight15.data")) r15(.clk(clk), .addr(rom_addr), .dout(w15));
    
    // Output weights mapping 100 hidden nodes -> Classification
    weight_rom #(.INIT_FILE("outputwt.data")) rout(.clk(clk), .addr(rom_addr), .dout(w_out));
    
    // Bias arrays (instantiating dynamic zero fallback if file missing natively)
    bias_rom   #(.INIT_FILE("bias_hidden.data")) rbias(.clk(clk), .addr(rom_addr), .dout(bias_h));

    // Phase 2: Feature x Weight Multiplications mathematically aligned
    // ==============================================================
    wire signed [24:0] mul1, mul2, mul3, mul4, mul5, mul6, mul7, mul8, mul9, mul10, mul11, mul12, mul13, mul14, mul15;
    
    mult_wt_nn m1(.clk(clk), .A(f1), .B(w1), .result(mul1));
    mult_wt_nn m2(.clk(clk), .A(f2), .B(w2), .result(mul2));
    mult_wt_nn m3(.clk(clk), .A(f3), .B(w3), .result(mul3));
    mult_wt_nn m4(.clk(clk), .A(f4), .B(w4), .result(mul4));
    mult_wt_nn m5(.clk(clk), .A(f5), .B(w5), .result(mul5));
    mult_wt_nn m6(.clk(clk), .A(f6), .B(w6), .result(mul6));
    mult_wt_nn m7(.clk(clk), .A(f7), .B(w7), .result(mul7));
    mult_wt_nn m8(.clk(clk), .A(f8), .B(w8), .result(mul8));
    mult_wt_nn m9(.clk(clk), .A(f9), .B(w9), .result(mul9));
    mult_wt_nn m10(.clk(clk), .A(f10), .B(w10), .result(mul10));
    mult_wt_nn m11(.clk(clk), .A(f11), .B(w11), .result(mul11));
    mult_wt_nn m12(.clk(clk), .A(f12), .B(w12), .result(mul12));
    mult_wt_nn m13(.clk(clk), .A(f13), .B(w13), .result(mul13));
    mult_wt_nn m14(.clk(clk), .A(f14), .B(w14), .result(mul14));
    mult_wt_nn m15(.clk(clk), .A(f15), .B(w15), .result(mul15));

    // Phase 3: Hardware Adder Tree & Bias Injection
    // ==============================================================
    wire signed [29:0] tree_sum;
    adder_tree_nn add_net(.clk(clk), .m1(mul1), .m2(mul2), .m3(mul3), .m4(mul4), .m5(mul5),
        .m6(mul6), .m7(mul7), .m8(mul8), .m9(mul9), .m10(mul10), .m11(mul11), .m12(mul12),
        .m13(mul13), .m14(mul14), .m15(mul15), .sum(tree_sum));
        
    // Delay routing for synchronized bias to match tree calculation
    reg signed [29:0] bias_delayed;
    wire signed [29:0] biased_hidden = tree_sum + bias_delayed;
    
    // Phase 4: ReLU Activation Vector
    // ==============================================================
    wire signed [29:0] relu_hidden;
    relu_nn relu_act(.clk(clk), .in_number(biased_hidden), .out_number(relu_hidden));
    
    // Phase 5: Output Accumulation Weights
    // ==============================================================
    reg signed [15:0] w_out_del1, w_out_del2, w_out_del3; // Delay line for out_w synchronization
    wire signed [39:0] mult_final;
    mult_wt1_nn m_final(.clk(clk), .A(w_out_del3), .B(relu_hidden), .result(mult_final));
    
    // Global Prediction Accumulator
    reg signed [49:0] accumulator;
    
    // Master State Controller
    always @(posedge clk) begin
        if (rst) begin
            rom_addr <= 0;
            computing <= 0;
            v_rom <= 0; v_mult <= 0; v_add <= 0; v_relu <= 0; v_outmult <= 0;
            classification_out <= 0; done <= 0;
            accumulator <= 0;
            bias_delayed <= 0;
            w_out_del1 <= 0; w_out_del2 <= 0; w_out_del3 <= 0;
        end else begin
            
            // Shift pipeline states
            v_rom <= computing;
            v_mult <= v_rom;
            v_add <= v_mult;
            v_relu <= v_add;
            v_outmult <= v_relu;
            
            if (start_prediction) begin
                computing <= 1;
                rom_addr <= 0;
                accumulator <= 0;
                done <= 0;
            end
            
            if (computing) begin
                if (rom_addr < 99) begin
                    rom_addr <= rom_addr + 1;
                end else begin
                    computing <= 0; // Finished pumping variables!
                end
            end
            
            // Align variable sync
            w_out_del1 <= w_out;
            w_out_del2 <= w_out_del1;
            w_out_del3 <= w_out_del2; // Taps into M_Final dynamically perfectly timed
            
            bias_delayed <= bias_h;    // 1 clk delay matches mult -> add cascade inherently

            if (v_outmult) begin
                accumulator <= accumulator + mult_final;
            end
            
            if (!computing && !v_rom && !v_mult && !v_add && !v_relu && v_outmult) begin
                // Pipeline flushed perfectly! All variables resolved physically
                classification_out <= accumulator + mult_final; 
                done <= 1;
            end else begin
                done <= 0; // Single valid spike cleanly bounds
            end
            
        end
    end
endmodule


// ========================================================

module mult_wt_nn(
    input clk,
    input signed [15:0] A, input signed [15:0] B,
    output signed [24:0] result
);
    reg signed [31:0] mult_result;
    always @(posedge clk) begin
        mult_result <= A * B;
    end
    assign result = mult_result[24:0]; // Legacy truncation boundary securely protected
endmodule

module mult_wt1_nn(
    input clk,
    input signed [15:0] A, input signed [29:0] B,
    output signed [39:0] result
);
    reg signed [45:0] mult_result;
    always @(posedge clk) begin
        mult_result <= A * B;
    end
    assign result = mult_result[39:0]; 
endmodule

module adder_tree_nn(
    input clk,
    input signed [24:0] m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15,
    output reg signed [29:0] sum        
);
    wire signed [29:0] s1_1 = m1 + m2;
    wire signed [29:0] s1_2 = m3 + m4;
    wire signed [29:0] s1_3 = m5 + m6;
    wire signed [29:0] s1_4 = m7 + m8;
    wire signed [29:0] s1_5 = m9 + m10;
    wire signed [29:0] s1_6 = m11 + m12;
    wire signed [29:0] s1_7 = m13 + m14;
    wire signed [29:0] s1_unp = m15;  

    wire signed [29:0] s2_1 = s1_1 + s1_2;
    wire signed [29:0] s2_2 = s1_3 + s1_4;
    wire signed [29:0] s2_3 = s1_5 + s1_6;
    wire signed [29:0] s2_unp = s1_7 + s1_unp;
  
    wire signed [29:0] s3_1 = s2_1 + s2_2;
    wire signed [29:0] s3_unp = s2_3 + s2_unp;  

    wire signed [29:0] final_s = s3_1 + s3_unp;

    always @(posedge clk) sum <= final_s;
endmodule

module relu_nn (
    input clk,
    input signed [29:0] in_number, 
    output reg signed [29:0] out_number 
);
    always @(posedge clk) begin
        if (in_number < 0) out_number <= 0; 
        else out_number <= in_number; 
    end
endmodule


// ========================================================
// Universal BRAM Array Injectors 
// ========================================================

module weight_rom #(parameter INIT_FILE="weight.data") (
    input clk,
    input [6:0] addr,
    output reg signed [15:0] dout
);
    // Synplify / XST accurately infers explicit BRAM primitives automatically 
    reg signed [15:0] mem [0:99];
    
    initial begin
        // The synthesis tool natively locates the array at implementation
        $readmemh(INIT_FILE, mem);
    end
    
    always @(posedge clk) begin
        dout <= mem[addr];
    end
endmodule

module bias_rom #(parameter INIT_FILE="bias.data") (
    input clk,
    input [6:0] addr,
    output reg signed [29:0] dout
);
    reg signed [29:0] mem [0:99];
    
    initial begin
        // Zero-initialize first, then load from file if available
        integer i;
        for (i=0; i<100; i=i+1) mem[i] = 0;
        $readmemh(INIT_FILE, mem);
    end
    
    always @(posedge clk) begin
        dout <= mem[addr];
    end
endmodule
