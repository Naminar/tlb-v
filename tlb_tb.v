
module tlb_tb;

    reg clk;
    // reg shutdown;
    // reg insert;
    // reg validate;

    // reg [SADDR-1:0] incoming_dtlb_va;
    // reg [SADDR-1:0] incoming_dtlb_pa = incoming_dtlb_va;
    // reg [SPCID-1:0] incoming_dtlb_pcid = 0;

    // reg [SADDR-1:0] incoming_itlb_va;
    // reg [SADDR-1:0] incoming_itlb_pa = incoming_itlb_va;
    // reg [SPCID-1:0] incoming_itlb_pcid = 0;

    // reg [SADDR-1:0] prefetching_stlb_va;
    // reg [SADDR-1:0] prefetching_stlb_pa = prefetching_stlb_va;
    // reg [SPCID-1:0] prefetching_stlb_pcid = 0;

    // reg prefetch_stlb;
    // reg dtlb_req;
    // reg itlb_req;

    // #TODO
    // PMU pmu(.clk(clk),
    //         .dtlb_hit(dtlb_hit), .dtlb_miss(dtlb_miss), .dtlb_insert(dtlb_insert),
    //         .itlb_hit(itlb_hit), .itlb_miss(itlb_miss), .itlb_insert(itlb_insert),
    //         .stlb_hit(stlb_hit), .stlb_miss(stlb_miss), .stlb_prefetch(stlb_prefetch), .stlb_insert(stlb_insert));

    MMU mmu(.clk(clk)); //, shutdown, insert, insert, validate, va, pa, pcid, ta);

    initial begin
        $dumpfile("tlb_tb.vcd");
        $dumpvars(0,tlb_tb);

        clk = 0;

        #100 $finish;
    end

    always #1 clk = ~clk;
endmodule