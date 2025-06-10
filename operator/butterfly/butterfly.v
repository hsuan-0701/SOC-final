// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : butterfly
// Author : Jeese , hsuanjung,Lo
// Create Date: 6/2025
// Features & Functions:
// .  
// . 
// ============================================================================================================================================================================
// Revision History:
// Date           by            Version       Change Description
// 
//
// 
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------


module butterfly
#(  
    parameter pDATA_WIDTH = 128 // two 64-bit numbers represent real & imaginary part
)
(
    input   wire clk,
    input   wire rstn,

    input   wire [1:0] mode, // FFT/iFFT/NTT/iNTT

    input   wire i_vld,
    output  wire i_rdy,
    
    output  wire o_vld,
    input   wire o_rdy,

    input   wire [(pDATA_WIDTH-1):0] ai,
    input   wire [(pDATA_WIDTH-1):0] bi,
    input   wire [(pDATA_WIDTH-1):0] gm, // constant
    
    output  wire [(pDATA_WIDTH-1):0] ao,
    output  wire [(pDATA_WIDTH-1):0] bo

);
localparam pFP_WIDTH        = 64 ;
localparam pMANTISSA_WIDTH  = 52 ;
localparam pEXP_WIDTH       = 11 ;

localparam pNTT_WIDTH       = 16 ;
localparam pWALLACE_WIDTH   = 131;
//--------------------------------------------------------------------------------------------------------------------//
localparam pROUNDER_FRAC_WIDTH = 106 ;
localparam pROUNDER_EXP_WIDTH  = 13  ;
//--------------------------------------------------------------------------------------------------------------------//
localparam TOTAL_LATENCY       = 22;  //* Latency of mode , to alignment the operator process with 19cycle we set mode latency.
localparam FP_ADD_LATENCY      = 5 ;  //* Latency of fp_add
localparam MUL16_ARRAY_LATENCY = 4 ;  //* Latency of mul_16 array
localparam WALLACE_LATENCY     = 3 ;  //* Latency of wallace tree
localparam EXP_OP_LATENCY      = 7 ;
localparam ROUNDER_LATENCY     = 3 ;  //* Latency of rounder
//--------------------------------------------------------------------------------------------------------------------//
localparam FFT      = 2'b11 ;
localparam IFFT     = 2'b10 ;
localparam INTT     = 2'b00 ;
localparam NTT      = 2'b01 ;
//=====================================================================================================================//
//--------------------------------------- INPUT INTERFACE  ------------------------------------------------------------//
reg                                 pip0_valid;
reg  [1:0]                          pip0_mode ;
reg  [(pDATA_WIDTH-1):0]            pip0_ai   ;
reg  [(pDATA_WIDTH-1):0]            pip0_bi   ;
reg  [(pDATA_WIDTH-1):0]            pip0_gm   ;
//-------------------------------------- DECODE (FFT fp data ) --------------------------------------------------------//
wire [(pFP_WIDTH-1) :0]             pip0_a_re ;
wire [(pFP_WIDTH-1) :0]             pip0_a_im ;
wire [(pFP_WIDTH-1) :0]             pip0_b_re ;
wire [(pFP_WIDTH-1) :0]             pip0_b_im ;
wire                                Cmul_valid ;
//---------------------------------------- fp_add(first) operand -------------------------------------------------------//
// * input of fp_add
wire [(pFP_WIDTH-1) : 0]            a_re     ;
wire [(pFP_WIDTH-1) : 0]            a_im     ;
wire [(pFP_WIDTH-1) : 0]            b_re     ;
wire [(pFP_WIDTH-1) : 0]            b_im     ;
wire [(pFP_WIDTH-1) : 0]            a_im_neg ;
wire [(pFP_WIDTH-1) : 0]            b_im_neg ;
// * result of fp_add
wire [(pFP_WIDTH-1) : 0]            ar_sub_ai    ;
wire [(pFP_WIDTH-1) : 0]            br_add_bi    ;
wire [(pFP_WIDTH-1) : 0]            br_sub_bi    ;
wire [2             : 0]            fp_add_ready ;
// * other operand (store in shift reg)
reg  [(pDATA_WIDTH-1): 0]           a_reg     [0:(FP_ADD_LATENCY-1)];
reg  [(pDATA_WIDTH-1): 0]           b_reg     [0:(FP_ADD_LATENCY-1)];
reg  [2              : 0]           mode_reg  [0:(FP_ADD_LATENCY-1)];
wire [(pFP_WIDTH-1)  : 0]           a_re_reg;
wire [(pFP_WIDTH-1)  : 0]           a_im_reg;
wire [(pFP_WIDTH-1)  : 0]           b_re_reg;
wire [(pFP_WIDTH-1)  : 0]           b_im_reg;
//---------------------------------------- fmul_exp  ---------------------------------------------------------------------//
wire [(pEXP_WIDTH-1):0]             exp_A0;
wire [(pEXP_WIDTH-1):0]             exp_A1;
wire [(pEXP_WIDTH-1):0]             exp_B0;
wire [(pEXP_WIDTH-1):0]             exp_B1;
wire [(pEXP_WIDTH-1):0]             exp_C0;
wire [(pEXP_WIDTH-1):0]             exp_C1;
// * exp operator output
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_A_out;
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_B_out;
wire [(pROUNDER_EXP_WIDTH-1):0]     exp_C_out;
wire                                inf_A ;
wire                                inf_B ;
wire                                inf_C ;
wire                                exp_ready_A;
wire                                exp_ready_B;
wire                                exp_ready_C;
// * sign bit of fp operand
wire                                sign_A ;
wire                                sign_B ;
wire                                sign_C ;
reg                                 sign_A_reg[0 :(EXP_OP_LATENCY-1)];
reg                                 sign_B_reg[0 :(EXP_OP_LATENCY-1)];
reg                                 sign_C_reg[0 :(EXP_OP_LATENCY-1)];
//---------------------------------------- mul_16 array (sharing) ---------------------------------------------------------//
wire                                array_in_valid   ;
wire[2:0]                           array_out_valid  ;
// * hidden bit of fp_mul operand
wire                                hidden_br_add_bi ;
wire                                hidden_a_im      ;
wire                                hidden_ar_sub_ai ;
wire                                hidden_b_im ;
wire                                hidden_br_sub_bi ;
wire                                hidden_a_re      ;
// * mul_16 array input data ( A、 B 、 C array)
wire [(pFP_WIDTH-1)  : 0]           array_in_A0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_A1      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_B0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_B1      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_C0      ;
wire [(pFP_WIDTH-1)  : 0]           array_in_C1      ;
// * mul_16 array output result (A、 B 、 C array)
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_a3[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_b3[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c0[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c1[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c2[0:3];
wire [(pNTT_WIDTH*2-1):0]           mul_16_result_c3[0:3];
//--------------------------------------------- Wallace tree ------------------------------------------------------------//
wire                                wallace_mode;
wire [2:0]                          wallace_out_valid;
wire [(pWALLACE_WIDTH-1):0]         wallace_in;
// * wallace tree output result(A 、 B 、 C tree)
wire [(pWALLACE_WIDTH-1):0]         wallace_out_A;
wire [(pWALLACE_WIDTH-1):0]         wallace_out_B;
wire [(pWALLACE_WIDTH-1):0]         wallace_out_C;
//--------------------------------------- fraction rounder --------------------------------------------------------------//
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_A_i;
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_B_i;
wire [(pROUNDER_FRAC_WIDTH-1):0]    frac_C_i;
wire [(pMANTISSA_WIDTH-1):0]        frac_A_rounded;
wire [(pMANTISSA_WIDTH-1):0]        frac_B_rounded;
wire [(pMANTISSA_WIDTH-1):0]        frac_C_rounded;
wire [(pEXP_WIDTH-1):0]             exp_A_rounded;
wire [(pEXP_WIDTH-1):0]             exp_B_rounded;
wire [(pEXP_WIDTH-1):0]             exp_C_rounded;
wire                                rounder_ready_A;
wire                                rounder_ready_B;
wire                                rounder_ready_C;
//-------------------------------------- fp_add 2 (complex mul result) -------------------------------------------------//
wire [(pFP_WIDTH-1):0]              FP_num_A;
wire [(pFP_WIDTH-1):0]              FP_num_B;
wire [(pFP_WIDTH-1):0]              FP_num_c;
wire [(pFP_WIDTH-1):0]              y_re;
wire [(pFP_WIDTH-1):0]              y_im;
wire                                cmul_im_ready;
wire                                cmul_re_ready;

//======================================================================================================================//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          INPUT INTERFACE                                                 //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        pip0_valid  <= 1'b0;
        pip0_mode   <= 2'd0;
        pip0_ai     <= {(pDATA_WIDTH){1'b0}};
        pip0_bi     <= {(pDATA_WIDTH){1'b0}};
        pip0_gm     <= {(pDATA_WIDTH){1'b0}};
    end else begin
        pip0_valid  <= i_vld;
        pip0_mode   <= mode ;
        pip0_ai     <= ai   ; 
        pip0_bi     <= bi   ;
        pip0_gm     <= gm   ;

    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                              DECODE                                                       //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign pip0_a_re  = pip0_ai [(pFP_WIDTH*2-1) :0];
assign pip0_a_im  = pip0_ai [(pFP_WIDTH-1)   :0];
assign pip0_b_re  = pip0_bi [(pFP_WIDTH*2-1) :0];
assign pip0_b_im  = pip0_bi [(pFP_WIDTH-1)   :0];
assign Cmul_valid = (pip0_mode == FFT)?  1'b1 : 1'b0;

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                       floating point adder 1                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign pip0_a_im_neg = { (~FFT_a_im[pFP_WIDTH-1]) , FFT_a_im[(pFP_WIDTH-2) : 0]} ;  // * inv the sign bit of a_im ( -a_im ).
assign pip0_b_im_neg = { (~FFT_b_im[pFP_WIDTH-1]) , FFT_b_im[(pFP_WIDTH-2) : 0]} ;  // * inv the sign bit of b_re ( -b_re ).

fp_add   fp_add_01( .in_A( pip0_b_re ) , .in_B( pip0_b_im )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( Cmul_valid )  , .result( br_add_bi ) , .out_valid( fp_add_ready[0] ));
fp_add   fp_add_02( .in_A( pip0_a_re ) , .in_B( pip0_a_im_neg ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( Cmul_valid )  , .result( ar_sub_ai ) , .out_valid( fp_add_ready[1] ));
fp_add   fp_add_03( .in_A( pip0_b_re ) , .in_B( pip0_b_im_neg ) , .clk( clk ) , .rst_n( rst_n )  , .in_valid( Cmul_valid )  , .result( br_sub_bi ) , .out_valid( fp_add_ready[2] ));

integer i ;

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        for(i=0 ; i< FP_ADD_LATENCY ; i=i+1)begin        
            a_reg[i]     <= {(pDATA_WIDTH){1'b0}};
            b_reg[i]     <= {(pDATA_WIDTH){1'b0}};
            mode_reg[i]  <= 2'd0;
        end
    end else begin
        a_reg[0]         <= pip0_ai  ;
        b_reg[0]         <= pip0_bi  ;
        mode_reg[0]      <= pip0_mode;
        for(i=1 ; i< FP_ADD_LATENCY ; i=i+1)begin        
            a_reg[i]     <= a_reg[i-1]   ;
            b_reg[i]     <= b_reg[i-1]   ;
            mode_reg[i]  <= mode_reg[i-1];
        end

    end
end

// * specify a_re 、 a_im 、 b_re 、 b_im from last reg of a_reg、 b_reg
assign a_re_reg = a_reg[FP_ADD_LATENCY-1][(pFP_WIDTH*2-1) : pFP_WIDTH];
assign a_im_reg = a_reg[FP_ADD_LATENCY-1][(pFP_WIDTH-1)   : 0];
assign b_re_reg = b_reg[FP_ADD_LATENCY-1][(pFP_WIDTH*2-1) : pFP_WIDTH];
assign b_im_reg = b_reg[FP_ADD_LATENCY-1][(pFP_WIDTH-1)   : 0];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                           mul_16_array for fp mul or int  mul (shared)                                   //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-----------------------------------------------------------------------------------------------------------//      
// * Use leading bit of mode to analyze operation type .                                                     //
//   If leading is "1" , we do FFT floating point operate.                                                   //
//   If leading is "0" , we do NTT integer operate.                                                          //
//                                                                                                           //
// * While doing FFT operation we feed data type { 11 , hidden_bit , mantissa} into mul_16 array.            //
//   (As IEEE 754 format : If exponent all zero ,hidden_bit will be 0 . Others will be 1 ).                  //
//                                                                                                           //
// * While doing NTT operation we feed data typr {a3 , a2 , a1 , a0} into mul_16 array.                      //
//-----------------------------------------------------------------------------------------------------------//

localparam mul_array_FFT = 1'b1;
localparam mul_array_NTT = 1'b0;

assign array_in_valid    = fp_add_ready[0];

assign hidden_br_add_bi  = |(br_add_bi [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]) ;
assign hidden_a_im       = |(a_re_reg  [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]); 
assign hidden_ar_sub_ai  = |(ar_sub_ai [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_b_im       = |(b_im_reg  [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_br_sub_bi  = |(br_sub_bi [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);
assign hidden_a_re       = |(a_re_reg  [(pFP_WIDTH-2) : pMANTISSA_WIDTH ]);       
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////   Change following assignment to feed other operand into mul_16 array   //////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
assign array_in_A0       = {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_br_add_bi , br_add_bi [(pMANTISSA_WIDTH-1):0]} ;
assign array_in_A1       = {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_a_im      , a_im_reg  [(pMANTISSA_WIDTH-1):0]};
assign array_in_B0       = (mode_reg[FP_ADD_LATENCY-1][1] == mul_array_FFT)? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_ar_sub_ai , ar_sub_ai [(pMANTISSA_WIDTH-1):0]} : a_reg[(pNTT_WIDTH*4-1) : 0];                
assign array_in_B1       = (mode_reg[FP_ADD_LATENCY-1][1] == mul_array_FFT)? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_b_im      , b_im_reg  [(pMANTISSA_WIDTH-1):0]} : b_reg[(pNTT_WIDTH*4-1) : 0];                   
assign array_in_C0       = (mode_reg[FP_ADD_LATENCY-1][1] == mul_array_FFT)? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_br_sub_bi , br_sub_bi [(pMANTISSA_WIDTH-1):0]} : a_reg[(pNTT_WIDTH*8-1) : (pNTT_WIDTH*4)];
assign array_in_C1       = (mode_reg[FP_ADD_LATENCY-1][1] == mul_array_FFT)? {{(pFP_WIDTH - pMANTISSA_WIDTH -1 ){1'b0}} , hidden_a_re      , a_re_reg  [(pMANTISSA_WIDTH-1):0]} : b_reg[(pNTT_WIDTH*8-1) : (pNTT_WIDTH*4)];
 

mul16_array mul16_array_a(
    //-------- input of mul_16_array(64bit data width)
    .in_A( array_in_A0 ),  .in_B( array_in_A1 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid ),  .out_valid( array_out_valid[0] ),
    //-------- result from mul_16 ---------//
    .result_00( mul_16_result_a0[0] ) , .result_01( mul_16_result_a0[1] ) , .result_02( mul_16_result_a0[2] ) , .result_03( mul_16_result_a0[3] ), 
    .result_10( mul_16_result_a1[0] ) , .result_11( mul_16_result_a1[1] ) , .result_12( mul_16_result_a1[2] ) , .result_13( mul_16_result_a1[3] ),
    .result_20( mul_16_result_a2[0] ) , .result_21( mul_16_result_a2[1] ) , .result_22( mul_16_result_a2[2] ) , .result_23( mul_16_result_a2[3] ),
    .result_30( mul_16_result_a3[0] ) , .result_31( mul_16_result_a3[1] ) , .result_32( mul_16_result_a3[2] ) , .result_33( mul_16_result_a3[3] ));

mul16_array mul16_array_b(
    .in_A( array_in_B0 ),  .in_B( array_in_B1 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid ),  .out_valid( array_out_valid[1] ),
    .result_00( mul_16_result_b0[0] ) , .result_01( mul_16_result_b0[1] ) , .result_02( mul_16_result_b0[2] ) , .result_03( mul_16_result_b0[3] ), 
    .result_10( mul_16_result_b1[0] ) , .result_11( mul_16_result_b1[1] ) , .result_12( mul_16_result_b1[2] ) , .result_13( mul_16_result_b1[3] ),
    .result_20( mul_16_result_b2[0] ) , .result_21( mul_16_result_b2[1] ) , .result_22( mul_16_result_b2[2] ) , .result_23( mul_16_result_b2[3] ),
    .result_30( mul_16_result_b3[0] ) , .result_31( mul_16_result_b3[1] ) , .result_32( mul_16_result_b3[2] ) , .result_33( mul_16_result_b3[3] )
);

mul16_array mul16_array_c(
    .in_A( array_in_C0 ),  .in_B( array_in_C1 ),  .clk( clk ),  .rst_n( rst_n ),  .in_valid( array_in_valid ),  .out_valid( array_out_valid[2] ),
    .result_00( mul_16_result_c0[0] ) , .result_01( mul_16_result_c0[1] ) , .result_02( mul_16_result_c0[2] ) , .result_03( mul_16_result_c0[3] ), 
    .result_10( mul_16_result_c1[0] ) , .result_11( mul_16_result_c1[1] ) , .result_12( mul_16_result_c1[2] ) , .result_13( mul_16_result_c1[3] ),
    .result_20( mul_16_result_c2[0] ) , .result_21( mul_16_result_c2[1] ) , .result_22( mul_16_result_c2[2] ) , .result_23( mul_16_result_c2[3] ),
    .result_30( mul_16_result_c3[0] ) , .result_31( mul_16_result_c3[1] ) , .result_32( mul_16_result_c3[2] ) , .result_33( mul_16_result_c3[3] )
);


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                         mantissa mul operator   (Wallace tree for fp_mul out mantissa)                   //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign wallace_mode = 1'b0;
assign wallace_in   = {(pWALLACE_WIDTH){1'b0}};

wallace_131 Wallace_tree_a(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,     // * mode 0 for partial product adder , mode 1 for long operand adder
    .in_valid( array_out_valid[0] )       , .out_valid( wallace_out_valid[0]  )   , .result( wallace_out_A ),  
//----------------------------- data input of mul operation(from mul_16_array) -----------------------------------------//
    .mul_result_00( mul_16_result_a0[0] ) , .mul_result_01( mul_16_result_a0[1] ) , .mul_result_02( mul_16_result_a0[2] ) , .mul_result_03( mul_16_result_a0[3] ) ,    
    .mul_result_10( mul_16_result_a1[0] ) , .mul_result_11( mul_16_result_a1[1] ) , .mul_result_12( mul_16_result_a1[2] ) , .mul_result_13( mul_16_result_a1[3] ) ,    
    .mul_result_20( mul_16_result_a2[0] ) , .mul_result_21( mul_16_result_a2[1] ) , .mul_result_22( mul_16_result_a2[2] ) , .mul_result_23( mul_16_result_a2[3] ) ,
    .mul_result_30( mul_16_result_a3[0] ) , .mul_result_31( mul_16_result_a3[1] ) , .mul_result_32( mul_16_result_a3[2] ) , .mul_result_33( mul_16_result_a3[3] ) ,  
//------------------------------ data input of add operation(131bit add) -----------------------------------------------//
    .in_A( wallace_in ),                  , .in_B( wallace_in )           
);

wallace_131 Wallace_tree_b(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,     
    .in_valid( array_out_valid[1] )       , .out_valid( wallace_out_valid[1] )    , .result( wallace_out_B ),  
    .mul_result_00( mul_16_result_b0[0] ) , .mul_result_01( mul_16_result_b0[1] ) , .mul_result_02( mul_16_result_b0[2] ) , .mul_result_03( mul_16_result_b0[3] ) ,    
    .mul_result_10( mul_16_result_b1[0] ) , .mul_result_11( mul_16_result_b1[1] ) , .mul_result_12( mul_16_result_b1[2] ) , .mul_result_13( mul_16_result_b1[3] ) ,    
    .mul_result_20( mul_16_result_b2[0] ) , .mul_result_21( mul_16_result_b2[1] ) , .mul_result_22( mul_16_result_b2[2] ) , .mul_result_23( mul_16_result_b2[3] ) ,
    .mul_result_30( mul_16_result_b3[0] ) , .mul_result_31( mul_16_result_b3[1] ) , .mul_result_32( mul_16_result_b3[2] ) , .mul_result_33( mul_16_result_b3[3] ) ,  
    .in_A( wallace_in ),                  , .in_B( wallace_in )           
);

wallace_131 Wallace_tree_c(
    .clk( clk )                           , .rst_n( rst_n )                       , .mode( wallace_mode ) ,  
    .in_valid( array_out_valid[2] )       , .out_valid( wallace_out_valid[2] )    , .result( wallace_out_C ),  
    .mul_result_00( mul_16_result_c0[0] ) , .mul_result_01( mul_16_result_c0[1] ) , .mul_result_02( mul_16_result_c0[2] ) , .mul_result_03( mul_16_result_c0[3] ) ,    
    .mul_result_10( mul_16_result_c1[0] ) , .mul_result_11( mul_16_result_c1[1] ) , .mul_result_12( mul_16_result_c1[2] ) , .mul_result_13( mul_16_result_c1[3] ) ,    
    .mul_result_20( mul_16_result_c2[0] ) , .mul_result_21( mul_16_result_c2[1] ) , .mul_result_22( mul_16_result_c2[2] ) , .mul_result_23( mul_16_result_c2[3] ) ,
    .mul_result_30( mul_16_result_c3[0] ) , .mul_result_31( mul_16_result_c3[1] ) , .mul_result_32( mul_16_result_c3[2] ) , .mul_result_33( mul_16_result_c3[3] ) ,  
    .in_A( wallace_in ),                  , .in_B( wallace_in )           
);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          Exponent operator                                               //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign exp_A0 = br_add_bi [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * b_re + b_im
assign exp_A1 = a_im_reg  [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * im part of a
assign exp_B0 = ar_sub_ai [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * a_re - a_im
assign exp_B1 = b_im_reg  [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * im part of b              
assign exp_C0 = br_sub_bi [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * b_re - b_im
assign exp_C1 = a_re_reg  [(pMANTISSA_WIDTH + pEXP_WIDTH - 1) :pMANTISSA_WIDTH];    // * re part of a

fmul_exp  exponent_op_A( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[0] ), .exp_A( exp_A0 ), .exp_B( exp_A1 ),  .exp_o( exp_A_out ), .out_inf( inf_A ) , .out_valid( exp_ready_A ));
fmul_exp  exponent_op_B( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[1] ), .exp_A( exp_B0 ), .exp_B( exp_B1 ),  .exp_o( exp_B_out ), .out_inf( inf_B ) , .out_valid( exp_ready_B ));
fmul_exp  exponent_op_C( .clk( clk ) , .rst_n( rst_n ), .in_valid( fp_add_ready[2] ), .exp_A( exp_C0 ), .exp_B( exp_C1 ),  .exp_o( exp_C_out ), .out_inf( inf_C ) , .out_valid( exp_ready_C ));

assign sign_A = (br_add_bi[pFP_WIDTH-1] ^ a_im_reg[pFP_WIDTH-1]) ;
assign sign_B = (ar_sub_ai[pFP_WIDTH-1] ^ b_im_reg[pFP_WIDTH-1]) ;
assign sign_C = (br_sub_bi[pFP_WIDTH-1] ^ a_re_reg[pFP_WIDTH-1]) ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        for(i=0 ; i<EXP_OP_LATENCY ; i=i+1)begin
            sign_A_reg[i] <= 1'b0;
            sign_B_reg[i] <= 1'b0;
            sign_C_reg[i] <= 1'b0;
        end
    end else begin
        sign_A_reg[0] <= sign_A; 
        sign_B_reg[0] <= sign_B;
        sign_C_reg[0] <= sign_C;
        for(i=1 ; i<EXP_OP_LATENCY ; i=i+1)begin
            sign_A_reg[i] <= sign_A_reg[i-1];
            sign_B_reg[i] <= sign_B_reg[i-1];
            sign_C_reg[i] <= sign_C_reg[i-1];
        end
    end
end

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          Rounding operator                                               //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign frac_A_i =  wallace_out_A[(pROUNDER_FRAC_WIDTH-1) :0] ;
assign frac_B_i =  wallace_out_B[(pROUNDER_FRAC_WIDTH-1) :0] ;
assign frac_C_i =  wallace_out_C[(pROUNDER_FRAC_WIDTH-1) :0] ; 

fmul_rounder rounder_A ( .frac_i( frac_A_i ) , .exp_i( exp_A_out ) , .frac_o( frac_A_rounded ) , .exp_o( exp_A_rounded ) , .inf_case( inf_A ) , .in_valid( exp_ready_A ) , .out_valid( rounder_ready_A ) , .clk( clk ) , .rst_n( rst_n ));
fmul_rounder rounder_B ( .frac_i( frac_B_i ) , .exp_i( exp_B_out ) , .frac_o( frac_B_rounded ) , .exp_o( exp_B_rounded ) , .inf_case( inf_B ) , .in_valid( exp_ready_B ) , .out_valid( rounder_ready_B ) , .clk( clk ) , .rst_n( rst_n ));
fmul_rounder rounder_C ( .frac_i( frac_C_i ) , .exp_i( exp_C_out ) , .frac_o( frac_C_rounded ) , .exp_o( exp_C_rounded ) , .inf_case( inf_C ) , .in_valid( exp_ready_C ) , .out_valid( rounder_ready_C ) , .clk( clk ) , .rst_n( rst_n ));

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                       floating point adder 2                                              //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign FP_num_A = {sign_A_reg[EXP_OP_LATENCY-1] , exp_A_rounded , frac_A_rounded };  // num_A = a_im * (b_re + b_im)
assign FP_num_B = {sign_B_reg[EXP_OP_LATENCY-1] , exp_B_rounded , frac_B_rounded };  // num_B = b_im * (a_re - a_im)
assign FP_num_c = {sign_C_reg[EXP_OP_LATENCY-1] , exp_C_rounded , frac_C_rounded };  // num_C = a_re * (b_re - b_im)



fp_add   fp_add_04( .in_A( FP_num_A ) , .in_B( FP_num_B )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( rounder_ready_A )  , .result( y_im ) , .out_valid( cmul_im_ready ));
fp_add   fp_add_05( .in_A( FP_num_B ) , .in_B( FP_num_c )     , .clk( clk ) , .rst_n( rst_n )  , .in_valid( rounder_ready_C )  , .result( y_re ) , .out_valid( cmul_re_ready ));













//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                         OUTPUT INTERFACE                                                 //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////















    // complex mul & add & sub for FFT/iFFT



    // Complex Multiplication:
    // y_re = (a_re * b_re) - (a_im * b_im)
    // y_im = (a_re * b_im) + (a_im * b_re)
    // Rewrite as:
    // y_re = a_re * (b_re - b_im) + b_im * (a_re - a_im)
    // y_im = a_im * (b_re + b_im) + b_im * (a_re - a_im)
    // It will reduce the mul usage from 4 to 3 since we reuse [b_im * (a_re - a_im)]

    // montgomery mul & add & sub for NTT/iNTT

endmodule

