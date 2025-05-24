`timescale 1ns/1ps
module mul64_tb
#();

    reg             mode;
    reg [15:0]      A;
    reg [15:0]      B;
    wire[31:0]     result;
    reg             in_valid;
    wire            out_valid;
    reg             clk;
    reg             rst_n;


    mul_16 mul_16_DUT (
        .in_a( A ),
        .in_b( B ),
        .in_valid( in_valid ),
        .out_valid( out_valid ),
        .result( result ),
        .clk( clk ),
        .rst_n( rst_n )
    );


    initial begin
        $fsdbDumpfile("mul_16.fsdb");
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
    reg[15:0]   in_A_list[0:99];
    reg[15:0]   in_B_list[0:99];
    reg[31:0]  golden_list[0:99];

// set pattern //
    initial begin
        Din_a = $fopen("./pat/A.dat" ,"r");
        Din_b = $fopen("./pat/B.dat" ,"r");
        Gin   = $fopen("./pat/GOLDEN.dat" , "r");
        if (Din_a == 0 || Din_b == 0 || Gin == 0) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<100 ;m=m+1)begin
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
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        for(i=0 ;i<100 ; i=i+1)begin
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
        for(j=0 ; j<100;j=j+1)begin
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
        input  [15:0]  in_1;
        input  [15:0]  in_2;
        begin
            @(posedge clk);
            @(posedge clk)            
            in_valid <= 1;
            mode     <= 0;
            A <= in_1;
            B <= in_2;
            @(posedge clk)
            in_valid <= 0;
            A <= 0;
            B <= 0;
        end
    endtask


    task out_check ;
        input   [31:0] answer;
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
