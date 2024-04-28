module set_tb;

    reg clk = 0;
    wire [63:0] out;
    // set set1 (.clk(clk), .block(out));
    set sets[2:0];

    initial begin
        $dumpfile("set_tb.vcd");
        $dumpvars(0,set_tb);
        $monitor("%t | clk = %d | out = %d", $time, clk, sets[0].blocks[0]);
        #100 $finish;
        // a = 0;
        // # 1 a = 1;
        // # 2 a = 0;
    end

    always @(posedge clk) begin
    sets[0].blocks[0] = 64'b1;
    end

    always #1 clk = ~clk; // each 1  new a 
    // always #3 b = ~b;
endmodule