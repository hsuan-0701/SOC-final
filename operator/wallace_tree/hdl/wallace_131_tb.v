`timescale 1ns/1ps
module mul64_tb
#();

    reg             mode;
    reg [130:0]      A;
    reg [130:0]      B;
    wire[130:0]     result;
    reg             in_valid;
    wire            out_valid;
    reg             clk;
    reg             rst_n;
    reg[31:0]       mul_0[0:3];
    reg[31:0]       mul_1[0:3];
    reg[31:0]       mul_2[0:3];
    reg[31:0]       mul_3[0:3];

    wallace_131 wallace_131_DUT (
        .mode( mode ),
        
        .in_A( A ),
        .in_B( B ),

        .in_valid( in_valid ),
        .out_valid( out_valid ),
        
        .result( result ),
        .clk( clk ),
        .rst_n( rst_n ),
        
        .mul_result_00(mul_0[0]),
    
        .mul_result_01(mul_0[1] ),
        .mul_result_10(mul_1[0] ),

        .mul_result_02(mul_0[2] ),
        .mul_result_20(mul_2[0] ),
        .mul_result_11(mul_1[1] ),
    
        .mul_result_03(mul_0[3] ),
        .mul_result_30(mul_3[0] ),
        .mul_result_21(mul_2[1] ),
        .mul_result_12(mul_1[2] ),

        .mul_result_31(mul_3[1] ),
        .mul_result_22(mul_2[2] ),
        .mul_result_13(mul_1[3] ),
    
        .mul_result_32(mul_3[2] ),
        .mul_result_23(mul_2[3] ),  

        .mul_result_33(mul_3[3] )  
    );


    initial begin
        $fsdbDumpfile("wallace_131.fsdb");
        $fsdbDumpvars("+mda");
    end

    initial begin
        clk = 0;
        forever begin
            #5 clk = (~clk);
        end
    end

    integer timeout = (100000);
    initial begin
        while(timeout > 0) begin
            @(posedge clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ....");
        $finish;
    end

    initial begin
        rst_n <= 1;
        @(negedge clk);
        #2
        rst_n <= 0; 
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        rst_n <= 1;
    end


    integer Din_a , Din_b ,Gin;
    integer a_in ,b_in ,g_in;
    integer m,n;
    reg[130:0]   in_A_list[0:9999];
    reg[130:0]   in_B_list[0:9999];
    reg[130:0]   golden_list[0:9999];

// set pattern //
    initial begin
        Din_a = $fopen("./pat/A.dat" ,"r");
        Din_b = $fopen("./pat/B.dat" ,"r");
        Gin   = $fopen("./pat/GOLDEN.dat" , "r");
        if (Din_a == 0 || Din_b == 0 || Gin == 0) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<10000 ;m=m+1)begin
                a_in = $fscanf(Din_a , "%d" , in_A_list[m]);
                b_in = $fscanf(Din_b , "%d" , in_B_list[m]);
                g_in = $fscanf(Gin   , "%d" , golden_list[m]);
            end
        end
        $display("------------ papttern initialize done --------------");
    end

//
    integer i;
    initial begin
        in_valid  <= 0;
        mode      <= 0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        for(i=0 ;i<10000 ; i=i+1)begin
            dat_in(in_A_list[i] , in_B_list[i]);
        end
    end

    integer j;

    reg error;
    
    initial begin
        error <=0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        for(j=0 ; j<10000;j=j+1)begin
            out_check(golden_list[j],j);
        end
        if(error==1)begin
            $display("----------- Simulation ERROR (QAQ)-------------------");
        end else begin
            $display("----------- Simulation PASS (^_^) -------------------");
        end
        $finish;
    end


    task dat_in ;
        input  [130:0]  in_1;
        input  [130:0]  in_2;
        begin
            @(posedge clk);
            @(posedge clk)            
            in_valid <= 1;
            mode     <= 1;
            A <= in_1;
            B <= in_2;
            @(posedge clk)
            in_valid <= 0;
            A <= 0;
            B <= 0;
        end
    endtask


    task out_check ;
        input   [130:0] answer;
        input   [31:0] ocnt;
        begin
            while (!out_valid) @(posedge clk);   
            if(result !== answer)begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", ocnt, answer, result);
                error <= 1;
            end else begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", ocnt, answer, result);
            end
            @(posedge clk);
        end
    endtask

endmodule