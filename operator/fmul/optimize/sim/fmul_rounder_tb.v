`timescale 1ns/1ps
module fmul_rounder_tb
#();

    reg [105:0]     frac_i;
    reg [12:0]      exp_i;
    reg             inf_case;
    wire[51:0]      frac_o;
    wire[10:0]      exp_o; 
    reg             in_valid;
    wire            out_valid;
    reg             clk;
    reg             rst_n;

    fmul_rounder fmul_rounder_DUT
    (
        .frac_i(frac_i) ,
        .exp_i(exp_i),
        .frac_o(frac_o),
        .exp_o(exp_o),
        .inf_case(inf_case ),
        .in_valid(in_valid),
        .out_valid(out_valid),
        .clk(clk),
        .rst_n(rst_n)
    );

    initial begin
        $fsdbDumpfile("fmul_rounder.fsdb");
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


    integer Din_a , Din_b , Din_c ,Gin_a  , Gin_b;
    integer a_in ,b_in , c_in , g_in_a , g_in_b ;
    integer m,n;

    reg[105:0]         in_frac_list[0:49999];
    reg signed[12:0]   in_exp_list[0:49999];
    reg                in_inf_list[0:49999];

    reg[51:0]   golden_list_frac[0:49999];
    reg[10:0]   golden_list_exp[0:49999];
// set pattern //
    initial begin
        Din_a = $fopen("./round_pat/frac_i.dat" ,"r");
        Din_b = $fopen("./round_pat/exp_i.dat" ,"r");
        Din_c = $fopen("./round_pat/inf_case.dat" , "r");
        Gin_a   = $fopen("./round_pat/golden_frac.dat" , "r");
        Gin_b   = $fopen("./round_pat/golden_exp.dat" , "r");
        if (Din_a == 0 || Din_b == 0 || Din_c == 0 || Gin_a == 0 || Gin_b == 0) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<50000 ;m=m+1)begin
                a_in   = $fscanf(Din_a , "%d" , in_frac_list[m]);
                b_in   = $fscanf(Din_b , "%d" , in_exp_list[m]);
                c_in   = $fscanf(Din_c , "%b" , in_inf_list[m]);

                g_in_a = $fscanf(Gin_a , "%d" , golden_list_frac[m]);
                g_in_b = $fscanf(Gin_b , "%d" , golden_list_exp[m]);
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
            dat_in(in_frac_list[i] , in_exp_list[i] , in_inf_list[i]);
        end
    end

    integer j;

    reg error;
    
    initial begin
        error <=0;
        wait(rst_n == 0);
        wait(rst_n == 1);
        @(posedge clk);
        for(j=0 ; j<50000;j=j+1)begin
            out_check(golden_list_frac[j], golden_list_exp[j] , j );
        end
        if(error==1)begin
            $display("----------- Simulation ERROR (QAQ)-------------------");
        end else begin
            $display("----------- Simulation PASS (^_^) -------------------");
        end
        $finish;
    end


    task dat_in ;
        input  [105:0]  in_1;
        input  [12:0]  in_2;
        input          in_3;
        begin
            @(posedge clk);
            @(posedge clk)            
            in_valid <= 1;
            frac_i   <= in_1;
            exp_i    <= in_2;
            inf_case <= in_3;
            @(posedge clk)
            in_valid <= 0;
            frac_i   <= 0;
            exp_i    <= 0;
            inf_case <= 0;
        end
    endtask


    task out_check ;
        input   [51:0] answer_frac;
        input   [10:0] answer_exp;
        input   [31:0] ocnt;
        begin
            while (!out_valid) @(posedge clk);   
            if( (frac_o !== answer_frac) || (exp_o !== answer_exp) )begin
                $display("[ERROR] [Pattern %d] Golden frac: %h, Your frac: %h", ocnt, answer_frac, frac_o);
                $display("[ERROR] [Pattern %d] Golden exp : %d, Your exp : %d", ocnt, answer_exp , exp_o);
                error <= 1;
            end else begin
                $display("[PASS] [Pattern %d] Golden frac: %h, Your frac: %h", ocnt, answer_frac, frac_o);
                $display("[PASS] [Pattern %d] Golden exp : %d, Your exp : %d", ocnt, answer_exp , exp_o);
            end
            @(posedge clk);
        end
    endtask

endmodule