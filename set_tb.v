module set_tb;

    reg clk;
    reg [63:0] in_addr;
    reg [11:0] in_pcid;
    wire [63:0] o_addr;
    wire [7:0] hit;

    cache TLB(clk, in_addr, in_pcid, o_addr, hit);

    initial begin
        $dumpfile("set_tb.vcd");
        $dumpvars(0,set_tb);
        $monitor("%t | clk = %d | out = %d", $time, clk, TLB._set_0.va[7]);

        clk = 0;

        in_addr = 64'hffffffffffffffff;
        in_pcid = 12'h0;

        #10
        in_addr = 64'h0;
        #10 
        in_addr = 64'hffffffffffffffff;

        #100 $finish;
    end

    always #1 clk = ~clk;
endmodule