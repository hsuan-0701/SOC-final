// -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//
// MIT License
// ---
// Copyright © 2023 Company
// .... Content of the license
// ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
// ============================================================================================================================================================================
// Module Name : LOD_64
// Author : Hsuan Jung,Lo
// Create Date: 5/2025
// Features & Functions:
// . To calculate the position of leading one.
// . 
// ============================================================================================================================================================================
// Revision History:
// Date         by      Version     Change Description
//  
// 
//
// ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

//==================================================================================================================================================================================
// 
// * In floating point operation we need to normalize the fraction and exponent to meet IEEE 754 double precision.
// * As IEEE 754 's rule we need to detect the leading one's position of fraction .
// * In LOD_64 we can input a 64bit width data,and return number of zero in front of leading one.
// 
//
// * Waveform：    
//          A     >|  xx  |  64'h0000_0000_0000_0001  |  64'h7056_4546_2301_0000  |    64'hffff_ffff_ffff_ffff     | * input data A
//      position  >|  xx  |         11'd63            |          11'd1            |         11'd0                  | * output position(number of zero in front of leading one)
//      
//===================================================================================================================================================================================


module LOD_64 #(
    parameter pDATA_WIDTH    = 64,
    parameter pCOUNTER_WIDTH = 11
)(
    input [(pDATA_WIDTH-1)   :0] A,
    output[(pCOUNTER_WIDTH-1):0] position
);

localparam pSECOND_WIDTH  = pDATA_WIDTH  /2;   //* 32
localparam pTHIRD_WIDTH   = pSECOND_WIDTH/2;   //* 16
localparam pFOURTH_WIDTH  = pTHIRD_WIDTH /2;   //* 8
localparam pFIFTH_WIDTH   = pFOURTH_WIDTH/2;   //* 4
localparam pSIXTH_WIDTH   = pFIFTH_WIDTH/2 ;   //* 2
// localparam pSEVENTH_WIDTH = pSIXTH_WIDTH/2 ;   //* 1


wire [5:0]                  data_chk;

wire [(pSECOND_WIDTH-1):0]  part_1;
wire [(pTHIRD_WIDTH-1):0]   part_2;
wire [(pFOURTH_WIDTH-1):0]  part_3;
wire [(pFIFTH_WIDTH-1):0]   part_4;
wire [(pSIXTH_WIDTH-1):0]   part_5;
// wire [(pSEVENTH_WIDTH-1):0] part_6;


assign data_chk[5] = |A     [(pDATA_WIDTH-1):pSECOND_WIDTH];   
assign data_chk[4] = |part_1[(pSECOND_WIDTH-1): pTHIRD_WIDTH];
assign data_chk[3] = |part_2[(pTHIRD_WIDTH-1) : pFOURTH_WIDTH];
assign data_chk[2] = |part_3[(pFOURTH_WIDTH-1): pFIFTH_WIDTH ];
assign data_chk[1] = |part_4[(pFIFTH_WIDTH-1) : pSIXTH_WIDTH ];
assign data_chk[0] = |part_5[(pSIXTH_WIDTH-1) ];
//assign data_chk[0] = |part_6[(pSEVENTH_WIDTH-1)];


 
assign	part_1	 = (data_chk[5]) ?      A[(pDATA_WIDTH-1):pSECOND_WIDTH]    :      A[(pSECOND_WIDTH-1):0]; 
assign	part_2 	 = (data_chk[4]) ? part_1[(pSECOND_WIDTH-1):pTHIRD_WIDTH]   : part_1[(pTHIRD_WIDTH-1):0];		
assign	part_3 	 = (data_chk[3]) ? part_2[(pTHIRD_WIDTH-1) :pFOURTH_WIDTH]  : part_2[(pFOURTH_WIDTH-1):0];		
assign	part_4 	 = (data_chk[2]) ? part_3[(pFOURTH_WIDTH-1):pFIFTH_WIDTH]   : part_3[(pFIFTH_WIDTH-1 ):0];		
assign  part_5   = (data_chk[1]) ? part_4[(pFIFTH_WIDTH-1 ):pSIXTH_WIDTH]   : part_4[(pSIXTH_WIDTH-1):0];		
//assign  part_6   = (data_chk[0]) ? part_5[(pSIXTH_WIDTH-1) :pSEVENTH_WIDTH] : part_5[(pSEVENTH_WIDTH-1):0];		


assign 	position = (|A) ? {{(pCOUNTER_WIDTH-6){1'b0}}, ~data_chk} : {{(pCOUNTER_WIDTH-8){1'b0}} , 8'd64} ;


endmodule
