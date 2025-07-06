module add_53_tb 
#();

    reg [52:0]   A;
    reg [52:0]   B;
    wire[53:0]   result;


    add_53 add_53_DUT(
        .in_A(A),
        .in_B(B),
        .result(result)
    );



    initial begin
        $fsdbDumpfile("add_53.fsdb");
        $fsdbDumpvars("+mda");
    end

    reg             clk;

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


    integer Din_a , Din_b ,Gin;
    integer a_in ,b_in ,g_in;
    integer m,n;
    reg[52:0]   in_A_list[0:4999];
    reg[52:0]   in_B_list[0:4999];
    reg[53:0]  golden_list[0:4999];

// set pattern //
    initial begin
        Din_a = $fopen("./add_pat/A.dat" ,"r");
        Din_b = $fopen("./add_pat/B.dat" ,"r");
        Gin   = $fopen("./add_pat/GOLDEN.dat" , "r");
        if (Din_a == 0 || Din_b == 0 || Gin == 0) begin
            $display("[ERROR] Failed to open pattern file....");
            $finish;
        end else begin 
            for(m=0 ; m<5000 ;m=m+1)begin
                a_in = $fscanf(Din_a , "%d" , in_A_list[m]);
                b_in = $fscanf(Din_b , "%d" , in_B_list[m]);
                g_in = $fscanf(Gin   , "%d" , golden_list[m]);
            end
        end
        $display("------------ papttern initialize done --------------");
    end

    integer i ,j;
    reg error;

    initial begin
        for(i=0 ; i<5000 ; i=i+1)begin
            #10
            A = in_A_list[i];
            B = in_B_list[i];
            #5
            if(result == golden_list[i])begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", i, golden_list[i] , result);
            end else begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", i, golden_list[i], result);
                error <= 1;
            end
            #10;
        end
        if(error==1)begin
            $display("----------- Simulation ERROR (QAQ)-------------------");
        end else begin
            $display("----------- Simulation PASS (^_^) -------------------");
        end
        $finish;
    end




endmodule
