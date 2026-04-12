`timescale 1ns / 1ps

module lwtbior(
    input clk,
    input rst,
    input signed [15:0] lwtinput,
    input valid_in,
    
    // Intermediate Debug Ports (preserved for backward compatibility with external Neural Net IPs)
    output signed [15:0] det1,
    output signed [15:0] sum,
    output signed [15:0] div,
    output signed [15:0] aprx1,
    output signed [15:0] det1_nrm,
    output signed [15:0] div1,
    output signed [15:0] div2,
    output signed [15:0] aprx1_nrm,
    
    output signed [15:0] det2,
    output signed [15:0] sum2,
    output signed [15:0] sum3,
    output signed [15:0] div21,
    output signed [15:0] div31,
    output signed [15:0] div32,
    output signed [15:0] aprx2,
    output signed [15:0] div22,
    output signed [15:0] det2_nrm,
    output signed [15:0] div222,
    output signed [15:0] aprx2_nrm,
    
    output signed [15:0] det3,
    output signed [15:0] aprx3,
    output signed [15:0] det3_nrm,
    output signed [15:0] div33,
    output signed [15:0] aprx3_nrm,
    
    // Feature Sync Outputs
    output valid_L1,
    output valid_L2,
    output valid_L3
);

    // Tie off unused debug registers to 0 to preserve the module port list without wasting LUT logic.
    assign sum = 0;   assign sum2 = 0;   assign sum3 = 0;
    assign div = 0;   assign div21= 0;   assign div31= 0;
    assign div1= 0;   assign div22= 0;   assign div32= 0;
    assign div2= 0;   assign div222=0;   assign div33= 0;

    // Stage 1 (Layer 1 CDF 5/3 LWT)
    lwt_stage stage1 (
        .clk(clk), .rst(rst),
        .data_in(lwtinput), 
        .valid_in(valid_in), 
        .raw_predict_det(det1), .raw_update_aprx(aprx1),
        .aprx_out(aprx1_nrm), .det_out(det1_nrm),
        .valid_out(valid_L1)
    );

    // Stage 2 (Layer 2)
    lwt_stage stage2 (
        .clk(clk), .rst(rst),
        .data_in(aprx1_nrm), 
        .valid_in(valid_L1), 
        .raw_predict_det(det2), .raw_update_aprx(aprx2),
        .aprx_out(aprx2_nrm), .det_out(det2_nrm),
        .valid_out(valid_L2)
    );

    // Stage 3 (Layer 3)
    lwt_stage stage3 (
        .clk(clk), .rst(rst),
        .data_in(aprx2_nrm), 
        .valid_in(valid_L2),
        .raw_predict_det(det3), .raw_update_aprx(aprx3),
        .aprx_out(aprx3_nrm), .det_out(det3_nrm),
        .valid_out(valid_L3)
    );

endmodule


module lwt_stage (
    input clk,
    input rst,
    input signed [15:0] data_in,
    input valid_in,
    
    // Intermediates outputs mapping
    output reg signed [15:0] raw_predict_det,
    output reg signed [15:0] raw_update_aprx,
    
    // Normalized cascade outputs
    output reg signed [15:0] aprx_out,
    output reg signed [15:0] det_out,
    output reg valid_out
);

    reg is_odd;
    reg compute_en;
    reg [2:0] prime_shift; // Warmup buffer state tracker
    
    // Phase 1: Isolated State Registration Buffers
    reg signed [15:0] even_prev;  // Holds even[n]   
    reg signed [15:0] even_curr;  // Holds even[n+1]
    reg signed [15:0] odd_curr;   // Holds odd[n]

    // Phase 2: Historical feature buffers
    reg signed [15:0] det_prev;   // Holds d[n-1]
    reg signed [15:0] aprx_prev;  // Holds a[n-1]

   
    always @(posedge clk) begin
        if (rst) begin
            is_odd <= 1'b0;
            even_prev <= 0;
            even_curr <= 0;
            odd_curr <= 0;
            compute_en <= 1'b0;
        end else if (valid_in) begin
            if (is_odd == 1'b0) begin
                even_prev <= even_curr;
                even_curr <= data_in; // We have sequenced [e_n, o_n, e_n+1], logic is ready
                compute_en <= 1'b1;   // Fire computation independently next clock edge
            end else begin
                odd_curr <= data_in;
                compute_en <= 1'b0;   // Wait for trailing even
            end
            is_odd <= ~is_odd;
        end else begin
            compute_en <= 1'b0;
        end
    end

    wire signed [31:0] sum_evens = even_prev + even_curr;
    wire signed [31:0] calc_det_raw = odd_curr - (sum_evens >>> 1);
    wire signed [15:0] calc_det = saturate16(calc_det_raw);

    // 2. Update (approx): a[n] = even[n] + (d[n] + d[n-1])/4 
    wire signed [31:0] sum_dets = calc_det_raw + det_prev; // det_prev is structurally d[n-1] right now
    wire signed [31:0] calc_aprx_raw = even_prev + (sum_dets >>> 2);
    wire signed [15:0] calc_aprx = saturate16(calc_aprx_raw);

    // 3. Normalization Mapping explicitly mapped from Original Neural Network Codebase
    // det_nrm(n) = det[n-1] - (det[n]>>>2)
    wire signed [31:0] norm_det_raw = det_prev - (calc_det_raw >>> 2);
    // aprx_nrm(n) = aprx[n] + (aprx[n-1]>>>1)
    wire signed [31:0] norm_aprx_raw = calc_aprx_raw + (aprx_prev >>> 1);

    
    always @(posedge clk) begin
        if (rst) begin
            det_prev <= 0;
            aprx_prev <= 0;
            
            raw_predict_det <= 0;
            raw_update_aprx <= 0;
            det_out <= 0;
            aprx_out <= 0;
            valid_out <= 1'b0;
            
            prime_shift <= 0;
        end else if (compute_en) begin
            // Increment warmup tracking until full
            if (prime_shift < 3'd3) begin
                prime_shift <= prime_shift + 1;
            end

            // Save historical math states for n-1 logic next clock cycle
            det_prev <= calc_det;
            aprx_prev <= calc_aprx;

            // Verbose debug ports mapping
            raw_predict_det <= calc_det;
            raw_update_aprx <= calc_aprx;

            // Saturated mathematical output emission
            det_out <= saturate16(norm_det_raw);
            aprx_out <= saturate16(norm_aprx_raw);

            // Supress emission during the garbage startup transient samples
            if (prime_shift >= 3'd2) begin
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

    // Internal safety function: prevents integer wrapping over large transient steps
    function signed [15:0] saturate16;
        input signed [31:0] val;
        begin
            if (val > 32'sd32767) saturate16 = 16'sd32767;
            else if (val < -32'sd32768) saturate16 = -16'sd32768;
            else saturate16 = val[15:0];
        end
    endfunction

endmodule
