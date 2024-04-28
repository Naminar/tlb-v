module set_tb;

    reg clk = 0;
    wire [63:0] out;
    // set sets[2:0];
    wire [63:0] in_addr = 64'hffffffffffffffff;
    wire [11:0] in_pcid = 12'h0;
    wire [63:0] o_addr;
    wire [7:0] hit;

    cache c(clk, in_addr, in_pcid, o_addr, hit);

    initial begin
        $dumpfile("set_tb.vcd");
        $dumpvars(0,set_tb);
        $monitor("%t | clk = %d | out = %d", $time, clk, c._set_0.hit);
        #100 $finish;
    end

    // always @(posedge clk) begin
    // sets[0].va[0] = 64'b1;
    // end

    always #1 clk = ~clk; // each 1  new a 
    // always #3 b = ~b;
endmodule