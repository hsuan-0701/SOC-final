module LOD_tb;
    reg [127:0] A;
    wire [10:0] result;

    LOD  LOD_DUT (
        .A(A),
        .position(result)
    );

    initial begin
        $fsdbDumpfile("LOD.fsdb");
        $fsdbDumpvars("+mda");
    end

    initial begin
        $display("==== LOD Testbench Start ====");

        A = 128'h0A45_8942;
        #10;
        $display("First input  = %b\nLeading one position = %d", A, result);

        A = 128'h00C4_5612;
        #10;
        $display("Second input = %b\nLeading one position = %d", A, result);

        A = 128'h8000_0000_0000_0000_0000_0000_0000_0000;
        #10;
        $display("third input    = %b\nLeading one position = %d", A, result);

        A = 128'h0000_0000_0000_0000_0000_0000_0000_0001;
        #10;
        $display("forth input    = %b\nLeading one position = %d", A, result);

        A = 128'h0000_0000_0000_0000_0000_0000_0000_0000;
        #10;
        $display("Zero input   = %b\nLeading one position = %d", A, result);

        $display("==== LOD Testbench End ====");
        $finish;
    end
endmodule

