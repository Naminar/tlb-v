module set_tb;

    reg clk;
    reg [63:0] va;
    reg [63:0] pa;
    reg [11:0] pcid;
    wire [63:0] o_addr;
    wire hit;
    wire miss;
    
    cache TLB(clk, va, pa, pcid, o_addr, hit, miss);

    initial begin
        $dumpfile("set_tb.vcd");
        $dumpvars(0,set_tb);
        // $monitor("%t | clk = %d | out = %d", $time, clk, TLB.gen_way._way_[3'd7]);

        clk = 0;
        pcid = 12'h0;

        va = 64'hfffffffffffffff1;
        pa = 0;

        #10
        va = 64'h0;
        pa = 0;
        #10 
        pcid = 1'b1;
        va = 64'hfffffffffffffff1;
        pa = 0;
        #10
        pcid = 1'b0;
        va = 64'hfffffffffffffff1;
        pa = 0;
        #10
        pcid = 1'b1;
        va = 64'hfffffffffffffff1;
        pa = 0;

        #100 $finish;
    end

    always #1 clk = ~clk;
endmodule