`timescale 1ns/1ps
module fmul_exp_tb
#();

    wire                   out_inf;
    reg [10:0]             A;
    reg [10:0]             B;
    wire signed[12:0]      result;
    reg                    in_valid;
    wire                   out_valid;
    reg                    clk;
    reg                    rst_n;


    fmul_exp fmul_exp_DUT(
        .out_inf(out_inf),
        .exp_A (A),
        .exp_B (B),
        .clk (clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .exp_o(result),
        .out_valid(out_valid)
    );


    initial begin
        $fsdbDumpfile("fmul_exp.fsdb");
        $fsdbDumpvars("+mda");
    end

    initial begin
        clk = 0;
        forever begin
            #5 clk = (~clk);
        end
    end

    integer timeout = (1000000);
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


    integer Din_a , Din_b , Din_c ,Gin;
    integer a_in ,b_in , c_in ,g_in;
    integer m,n;
    reg[10:0]   in_A_list[0:49999];
    reg[10:0]   in_B_list[0:49999];
    reg                golden_inf_list[0:49999];
    reg signed[12:0]   golden_list[0:49999];
// set pattern //
    initial begin
        Din_a = $fopen("./exp_pat/exp_A.dat" ,"r");
        Din_b = $fopen("./exp_pat/exp_B.dat" ,"r");
        Din_c = $fopen("./exp_pat/out_inf.dat" ,"r");
        Gin   = $fopen("./exp_pat/exp_golden.dat" , "r");
        if (Din_a == 0 || Din_b == 0 || Gin == 0 || Din_c == 0 ) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<50000 ;m=m+1)begin
                a_in = $fscanf(Din_a , "%d" , in_A_list[m]);
                b_in = $fscanf(Din_b , "%d" , in_B_list[m]);
                c_in = $fscanf(Din_c , "%b" , golden_inf_list[m]);
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
        for(i=0 ;i<50000 ; i=i+1)begin
            dat_in(in_A_list[i] , in_B_list[i] );
        end
    end


    integer j;

    reg error;
    wire ZERO_EXP;

    assign ZERO_EXP = 11'd0;
    initial begin
        error <=0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        for(j=0 ; j<50000;j=j+1)begin
            out_check(golden_list[j]  , golden_inf_list[j] ,j);
        end
        if(error==1)begin
            $display("----------- Simulation ERROR (QAQ)-------------------");
        end else begin
            $display("----------- Simulation PASS (^_^) -------------------");
        end
        $finish;
    end


    task dat_in ;
        input  [10:0]  in_1;
        input  [10:0]  in_2;

        begin
            @(posedge clk);
            @(posedge clk)            
            in_valid  <= 1;
            A         <= in_1;
            B         <= in_2;
            @(posedge clk)
            in_valid <= 0;
            A <= 0;
            B <= 0;
        end
    endtask


    task out_check ;
        input signed  [12:0] answer;
        input                inf_answer;
        input   [31:0] ocnt;
        begin
            while (!out_valid) @(posedge clk);   
            if(( result !== answer ) || (out_inf !== inf_answer ))begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", ocnt, answer, result);
                $display("[ERROR] [Pattern %d] Golden inf   : %b, Your inf   : %b", ocnt, inf_answer, out_inf);
                error <= 1;
            end else begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", ocnt, answer, result);
                $display("[PASS] [Pattern %d] Golden inf   : %b, Your inf   : %b", ocnt, inf_answer, out_inf);
            end
            @(posedge clk);
        end
    endtask

endmodule