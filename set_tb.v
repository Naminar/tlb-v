module set_tb;

    reg clk;
    reg [63:0] va;
    reg [63:0] pa;
    reg [11:0] pcid;
    wire [63:0] o_addr;
    wire [7:0] hit;

    cache TLB(clk, va, pa, pcid, o_addr, hit);

    initial begin
        $dumpfile("set_tb.vcd");
        $dumpvars(0,set_tb);
        $monitor("%t | clk = %d | out = %d", $time, clk, TLB._set_0.va[7]);

        clk = 0;
        pcid = 12'h0;

        va = 64'hffffffffffffffff;
        pa = 0;

        #10
        va = 64'h0;
        pa = 0;
        #10 
        va = 64'hffffffffffffffff;
        pa = 0;

        #100 $finish;
    end

    always #1 clk = ~clk;
endmodule