module tlb_tb;

    reg clk;
    reg shutdown;
    reg insert;
    reg [63:0] va;
    reg [63:0] pa;
    reg [11:0] pcid;
    wire [63:0] o_addr;
    wire hit;
    wire miss;
    wire [63:0] stat_hit;
    wire [63:0] stat_miss;
    wire [63:0] stat_prefetch;
    
    cache TLB(clk, shutdown, insert, va, pa, pcid, o_addr, hit, miss);
    mmu MMU(clk, hit, miss, insert, stat_hit, stat_miss, stat_prefetch);
    
    initial begin
        $dumpfile("tlb_tb.vcd");
        $dumpvars(0,tlb_tb);
        // $monitor("");
        $monitor("%t | clk = %d | pcid = %d | plru = %b | tlb hit = %b | tlb miss = %b | %d | %d | %d | %d", $time, clk, TLB.ways[7].w.pcid[3'd7], TLB.plru[3'd7], TLB.hit, TLB.miss, TLB.ways[7].w.pcid[3'd7], TLB.ways[7].w.tag[3'd7], TLB.ways[3].w.pcid[3'd7], TLB.ways[3].w.tag[3'd7]);

        clk = 0;
        shutdown = 0;
        insert = 0;
        
        pcid = 1'b0;
        va = 64'hfffffffffffffff1;
        pa = 0;

        #10

        #1 
        assign shutdown = 1;
        #1
        assign shutdown = 0;
        #1

        assign insert = 1;
        pcid = 1'b0;
        va = 64'hfffffffffffffff1;
        pa = 0;
        #4
        assign insert = 0; 
        #1

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