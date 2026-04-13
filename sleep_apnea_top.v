`timescale 1ns / 1ps


// Top Level Sleep Apnea Classifier System
// Perfectly coordinates IIR -> LWT -> 15 Features -> Wide Neural Network
// 

module sleep_apnea_top(
    input clk,
    input rst,
    input valid_in, 
    input signed [15:0] ecg_data_in,
    
    // Final classification boundary output
    output signed [49:0] classification_out,
    output prediction_valid
);

   
    wire signed [15:0] iir_out;
    wire valid_iir;
    
    myiir filter_sos (
        .clk(clk), .rst(rst),
        .linput(ecg_data_in), .valid_in(valid_in),
        .myiir_out(iir_out), .valid_out(valid_iir)
    );

   
    wire signed [15:0] cd1, cd2, cd3, ca3;
    wire valid_l1, valid_l2, valid_l3;
    
    lwtbior wavelet_transform (
        .clk(clk), .rst(rst),
        .lwtinput(iir_out), .valid_in(valid_iir),
        
        .det1_nrm(cd1),    // CD1
        .det2_nrm(cd2),    // CD2
        .det3_nrm(cd3),    // CD3
        .aprx3_nrm(ca3),   // CA3
        
        .valid_L1(valid_l1),
        .valid_L2(valid_l2),
        .valid_L3(valid_l3)
    );

    
    
    // Level 1 (CD1) Extractors
    wire signed [15:0] feat_mean_cd1; wire done_m_cd1;
    absolutemean core_mean1(.clk(clk), .rst(rst), .linput(cd1), .valid_in(valid_l1), .mean(feat_mean_cd1), .start_m1(done_m_cd1));

    wire signed [15:0] feat_kurt_cd1; wire done_k_cd1;
    kurt core_kurt1(.clk(clk), .rst(rst), .linput1(cd1), .valid_in(valid_l1), .kurt1(feat_kurt_cd1), .startk1(done_k_cd1));

    wire signed [15:0] feat_teo_cd1; wire done_t_cd1;
    aadnle core_teo1(.clk(clk), .rst(rst), .linput(cd1), .valid_in(valid_l1), .nle(feat_teo_cd1), .startad3(done_t_cd1));

    wire signed [35:0] feat_var_cd1_36bit; wire signed [15:0] feat_hm_cd1; wire done_v_cd1;
    mfactor core_var1(.clk(clk), .rst(rst), .linput(cd1), .valid_in(valid_l1), .variance1(feat_var_cd1_36bit), .mfactor(feat_hm_cd1), .start_mob(done_v_cd1));
    wire signed [15:0] feat_var_cd1 = feat_var_cd1_36bit[15:0]; // Safe downcast mapping

    // Level 2 (CD2) Extractors
    wire signed [15:0] feat_mean_cd2; wire done_m_cd2;
    absmean2 core_mean2(.clk(clk), .rst(rst), .linput(cd2), .valid_in(valid_l2), .mean(feat_mean_cd2), .start_m2(done_m_cd2));

    // Level 3 (CD3) Extractors
    wire signed [15:0] feat_mean_cd3; wire done_m_cd3;
    absmean3 core_mean3(.clk(clk), .rst(rst), .linput(cd3), .valid_in(valid_l3), .mean(feat_mean_cd3), .startm3(done_m_cd3));

    wire signed [15:0] feat_kurt_cd3; wire done_k_cd3;
    kurt_two core_kurt3(.clk(clk), .rst(rst), .linput2(cd3), .valid_in(valid_l3), .kurt2(feat_kurt_cd3), .startk3(done_k_cd3));

    wire signed [15:0] feat_teo_cd3, feat_aad_cd3; wire done_ta_cd3;
    aadnle3 core_teo3(.clk(clk), .rst(rst), .linput3(cd3), .valid_in(valid_l3), .nle3(feat_teo_cd3), .aad33(feat_aad_cd3), .startad3(done_ta_cd3));

    wire signed [15:0] feat_if_cd3, feat_hm_cd3; wire done_h_cd3;
    mobthr core_hm3(.clk(clk), .rst(rst), .linput3(cd3), .valid_in(valid_l3), .irreg3(feat_if_cd3), .mobthr(feat_hm_cd3), .start(done_h_cd3));

    // Level 3 (CA3) Extractors
    wire signed [15:0] feat_kurt_ca3; wire done_k_ca3;
    kurtaprx core_kurtca3(.clk(clk), .rst(rst), .linput23(ca3), .valid_in(valid_l3), .kurtaprx23(feat_kurt_ca3), .starta3(done_k_ca3));

    wire signed [15:0] feat_teo_ca3; wire done_t_ca3;
    aadnle_a3 core_teoca3(.clk(clk), .rst(rst), .linput3(ca3), .valid_in(valid_l3), .nle3(feat_teo_ca3), .starta3(done_t_ca3));

    wire signed [15:0] feat_hm_ca3; wire done_h_ca3;
    moba3 core_hmca3(.clk(clk), .rst(rst), .linput3(ca3), .valid_in(valid_l3), .mobil(feat_hm_ca3), .starta3(done_h_ca3));

    
    // Wait until ALL 12 physical blocks (representing 15 logical features) independently finish calculating
    wire all_features_ready = (
        done_m_cd1 & done_k_cd1 & done_t_cd1 & done_v_cd1 &
        done_m_cd2 & 
        done_m_cd3 & done_k_cd3 & done_ta_cd3 & done_h_cd3 &
        done_k_ca3 & done_t_ca3 & done_h_ca3
    );

 
    // Standard ordered array natively routed perfectly to network instance
    neuralnet_top classification_ann (
        .clk(clk), .rst(rst),
        .start_prediction(all_features_ready), 
        
        .f1(feat_mean_cd1), 
        .f2(feat_var_cd1), 
        .f3(feat_kurt_cd1), 
        .f4(feat_hm_cd1),
        .f5(feat_kurt_cd3),
        .f6(feat_kurt_ca3),
        .f7(feat_mean_cd2),
        .f8(feat_mean_cd3),
        .f9(feat_hm_ca3),
        .f10(feat_teo_cd1),
        .f11(feat_teo_ca3),
        .f12(feat_teo_cd3),
        .f13(feat_if_cd3),
        .f14(feat_aad_cd3),
        .f15(feat_hm_cd3),

        .classification_out(classification_out),
        .done(prediction_valid)
    );

endmodule
