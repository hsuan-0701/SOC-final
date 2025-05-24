module CLA_8_err(
    input                   Cin,
    input   wire[7:0]       A,
    input   wire[7:0]       B,
    output  wire[8:0]       result
);

reg [7:0]             G;
reg [7:0]             P;
reg [7:0]             C;
reg [7:0]             S;

    //assign result = {C[7] , S[7] , S[6] , S[5] , S[4] , S[3] , S[2] , S[1] , S[0]}; 

    assign result = A+ B + {7'd0,Cin};

    always @(*)begin
        C[0] = G[0] | (Cin & P[0]);
        C[1] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & Cin);
        C[2] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & Cin);
        C[3] = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & P[0] & Cin);
        C[4] = G[4] | (P[4] & G[3]) | (P[4] & P[3] & G[2]) | (P[4] & P[3] & P[2] & G[1]) | (P[4] & P[3] & P[2] & P[1] & P[0] & Cin);
        C[5] = G[5] | (P[5] & G[4]) | (P[5] & P[4] & G[3]) | (P[5] & P[4] & P[3] & G[2]) | (P[5] & P[4] & P[3] & P[2] & G[1]) | (P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & Cin);
        C[6] = G[6] | (P[6] & G[5]) | (P[6] & P[5] & G[4]) | (P[6] & P[5] & P[4] & G[3]) | (P[6] & P[5] & P[4] & P[3] & G[2]) | (P[6] & P[5] & P[4] & P[3] & P[2] & G[1]) | (P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & Cin);
        C[7] = G[7] | (P[7] & G[6]) | (P[7] & P[6] & G[5]) | (P[7] & P[6] & P[5] & G[4]) | (P[7] & P[6] & P[5] & P[4] & G[3]) | (P[7] & P[6] & P[5] & P[4] & P[3] & G[2]) | (P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & G[1]) | (P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & Cin);
    end

    always @(*) begin
        S[0] = A[0] ^ B[0] ^ Cin ;
        S[1] = A[1] ^ B[1] ^ C[0];
        S[2] = A[2] ^ B[2] ^ C[1];
        S[3] = A[3] ^ B[3] ^ C[2];
        S[4] = A[4] ^ B[4] ^ C[3];
        S[5] = A[5] ^ B[5] ^ C[4];
        S[6] = A[6] ^ B[6] ^ C[5];
        S[7] = A[7] ^ B[7] ^ C[6];
    end


    integer i;
    always @(*) begin
        for(i=0 ; i<8 ;i=i+1)begin
            G[i] = A[i] & B[i];
            P[i] = A[i] ^ B[i];
        end
    end
endmodule

module CLA_8(
    input  wire        Cin,
    input  wire [7:0]  A,
    input  wire [7:0]  B,
    output wire [8:0]  result
);

    reg [7:0] G, P, S;
    reg [8:0] C;  // 包含 Cin 到 Cout（C[8]）

    assign result = {C[8], S}; // 最終輸出 = {最終進位, 8-bit sum}

       integer i;
    always @(*) begin
        // Generate and Propagate 計算
 
        for (i = 0; i < 8; i = i + 1) begin
            G[i] = A[i] & B[i];
            P[i] = A[i] ^ B[i];
        end

        // 初始化 Cin 為 C[0]
        C[0] = Cin;

        // Carry Lookahead 運算
        C[1] = G[0] | (P[0] & C[0]);
        C[2] = G[1] | (P[1] & G[0]) | (P[1] & P[0] & C[0]);
        C[3] = G[2] | (P[2] & G[1]) | (P[2] & P[1] & G[0]) | (P[2] & P[1] & P[0] & C[0]);
        C[4] = G[3] | (P[3] & G[2]) | (P[3] & P[2] & G[1]) | (P[3] & P[2] & P[1] & G[0]) | (P[3] & P[2] & P[1] & P[0] & C[0]);
        C[5] = G[4] | (P[4] & G[3]) | (P[4] & P[3] & G[2]) | (P[4] & P[3] & P[2] & G[1]) | (P[4] & P[3] & P[2] & P[1] & G[0]) | (P[4] & P[3] & P[2] & P[1] & P[0] & C[0]);
        C[6] = G[5] | (P[5] & G[4]) | (P[5] & P[4] & G[3]) | (P[5] & P[4] & P[3] & G[2]) | (P[5] & P[4] & P[3] & P[2] & G[1]) | (P[5] & P[4] & P[3] & P[2] & P[1] & G[0]) | (P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & C[0]);
        C[7] = G[6] | (P[6] & G[5]) | (P[6] & P[5] & G[4]) | (P[6] & P[5] & P[4] & G[3]) | (P[6] & P[5] & P[4] & P[3] & G[2]) | (P[6] & P[5] & P[4] & P[3] & P[2] & G[1]) | (P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & G[0]) | (P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & C[0]);
        C[8] = G[7] | (P[7] & G[6]) | (P[7] & P[6] & G[5]) | (P[7] & P[6] & P[5] & G[4]) | (P[7] & P[6] & P[5] & P[4] & G[3]) | (P[7] & P[6] & P[5] & P[4] & P[3] & G[2]) | (P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & G[1]) | (P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & G[0]) | (P[7] & P[6] & P[5] & P[4] & P[3] & P[2] & P[1] & P[0] & C[0]);
    end

    always @(*) begin
        for (i = 0; i < 8; i = i + 1)begin
            S[i] = P[i] ^ C[i];
        end
    end

endmodule
