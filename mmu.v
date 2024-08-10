`include "inc/state.v"

module MMU
(
    input clk,
    input shutdown,
    input ex_tlb_insert,
    input ex_stlb_insert,
    input validate,
    input [63:0] va,
    input [63:0] ex_pa,
    input [11:0] pcid,
    output reg [63:0] ta
);
    wire tlb_hit;
    wire stlb_hit;
    wire tlb_miss;
    wire stlb_miss;
    wire [63:0] stat_hit;
    wire [63:0] stat_miss;
    wire [63:0] stat_prefetch;

    reg tlb_insert;
    reg stlb_insert;
    reg [63:0] pa;
    reg ctrl = 1'b0;

    parameter SADDR=64;
    parameter SPCID=12;
    wire  [SADDR-1:0] tlb_req_va;
    wire  [SPCID-1:0] tlb_req_pcid;
    wire  [SADDR-1:0] tlb_insert_va;
    wire  [SADDR-1:0] tlb_insert_pa;
    wire  [SPCID-1:0] tlb_insert_pcid;
    wire  [SADDR-1:0] tlb_req_ta;
    reg [`STATE_RANGE] tlb_state = 6'b000001;
    reg [`STATE_RANGE] stlb_state = 6'b000001;


    TLB tlb(clk, tlb_state, tlb_req_va, tlb_req_pcid,
                tlb_insert_va, tlb_insert_pa, tlb_insert_pcid,
                // outputs
                tlb_req_ta, tlb_hit, tlb_miss);
    // PMU pmu(clk, tlb_hit, tlb_miss, tlb_insert, stlb_hit, stlb_miss, stlb_insert, stat_hit, stat_miss, stat_prefetch);
    // STLB stlb(clk, tlb_miss, shutdown, stlb_insert, validate, va, pa, pcid, ta, stlb_hit, stlb_miss);

// fancy inclusion policy
    // always @(posedge clk) begin
    //     tlb_insert  <= ex_tlb_insert;
    //     stlb_insert <= ex_stlb_insert;
    //     pa <= ex_pa;
    //     if (tlb_miss)
    //         ctrl <= 1'b1;
    //     if (ctrl && stlb_hit) begin
    //         tlb_insert <= 1'b1;
    //         ctrl <= 1'b0;
    //         pa <= ta; // for tlb insertion: pa is a source
    //     end else if (ctrl && stlb_miss) begin
    //         tlb_insert <= 1'b1;
    //         ctrl <= 1'b0;
    //     end
/********************************************************************
                             PIPELINE MACHINE
********************************************************************/

    reg [SADDR-1:0] piping_va   [5:0];       // virtual address
    reg [SADDR-1:0] piping_pa   [5:0];       // physical address
    reg [SPCID-1:0] piping_pcid [5:0];     // process-context identifier
    reg [SADDR-1:0] piping_ta   [5:0];  // translated address

    reg [SADDR-1:0] inter_piping_va;
    reg [SADDR-1:0] inter_piping_pa;
    reg [SPCID-1:0] inter_piping_pcid;
    reg [SADDR-1:0] inter_piping_ta;

/* verilator lint_off STMTDLY */
    initial begin
    inter_piping_va = 64'hfffffffffffffff1;
    inter_piping_pcid = 12'b0;
    inter_piping_pa = 64'hfffffffffffffff2;
    #4
    inter_piping_va =  64'h0;
    inter_piping_pcid = 12'b0;
    inter_piping_pa = 64'h1;
    #4
    inter_piping_va =  64'h1;
    inter_piping_pcid = 12'b0;
    inter_piping_pa = 64'h2;
    end
/* verilator lint_off STMTDLY */

    reg [SADDR-1:0] prev_va = 0;
    reg [SPCID-1:0] prev_pcid = 0;

    assign  tlb_req_va      = piping_va[0];
    assign  tlb_req_pcid    = piping_pcid[0];
    assign  tlb_insert_va   = piping_va[3];
    assign  tlb_insert_pa   = piping_pa[3];
    assign  tlb_insert_pcid = piping_pcid[3];

    // wire lock_bank0; // connect with outputs state of banks and request signal.
    // wire lock_bank1;
    // wire lock_bank2;
    // wire lock_bank3;

    always @(negedge clk) begin
        /* -------------- TLB PIPELINE -------------- */
        if (piping_va[0] != inter_piping_va || piping_pcid[0] != inter_piping_pcid) begin
            // prev_va <= inter_piping_va;
            // prev_pcid <= inter_piping_pcid;
            tlb_state`req_bit <= 1'b1;
        end else if (tlb_hit || tlb_miss) begin
            tlb_state`req_bit <= 1'b0;
        end

        // if (tlb_state`miss_bit == 1'b1) begin
        if (tlb_miss) begin
            // tlb_state`miss_bit <= 1'b0;
            stlb_state`req_bit <= 1'b1;
        end

        if (tlb_state`insert_bit == 1'b1) begin
            tlb_state`insert_bit <= 1'b0;
        end

        if (tlb_hit) begin
            // tlb_state`req_bit <= 1'b0;
            // piping_ta[0] = tlb_req_ta;
            ta <= tlb_req_ta;
        end

        if (tlb_miss) begin
            // tlb_state`req_bit <= 1'b0;
            tlb_state`miss_bit <= 1'b1;
        end else if (tlb_state`miss_bit == 1'b1) begin
            tlb_state`miss_bit <= 1'b0;
        end

        /* -------------- STLB PIPELINE -------------- */
        if (tlb_miss) begin
            stlb_state`req_bit <= 1'b1;
        end else if (stlb_hit || stlb_miss) begin
            stlb_state`req_bit <= 1'b0;
        end

        if (stlb_state`insert_bit == 1'b1) begin
            stlb_state`insert_bit <= 1'b0;
        end

        if (stlb_hit) begin
            // stlb_state`req_bit <= 1'b0;
            ta <= tlb_req_ta;
        end

        if (stlb_state`miss_bit == 1'b1) begin
            tlb_state`insert_bit  <= 1'b1;
            stlb_state`insert_bit <= 1'b1;
        end

        if (stlb_miss) begin
            // stlb_state`req_bit <= 1'b0;
            stlb_state`miss_bit <= 1'b1;
        end else if (stlb_state`miss_bit == 1'b1) begin
            stlb_state`miss_bit <= 1'b0;
        end

        // /* -------------- STLB PIPELINE -------------- */

        // If there is a task, do:
        // tlb_state`req_bit <= 1'b1;

        // tlb_state`req_bit <= 1'b1;

        // /* -------------- STLB PIPELINE -------------- */
        // if (stlb_state`miss_bit == 1'b1) begin
        //     stlb_state`miss_bit <= 1'b0;
        // end

        // if (stlb_state`insert_bit == 1'b1) begin
        //     stlb_state`insert_bit <= 1'b0;
        // end

        // if (stlb_hit) begin
        //     stlb_state`req_bit <= 1'b0;
        //     ta <= tlb_req_ta;
        // end

        // if (tlb_miss) begin
        //     stlb_state`req_bit <= 1'b0;
        //     stlb_state`miss_bit <= 1'b1;
        // end

        /* -------------- DATA PIPING -------------- */
        piping_va[5] <= piping_va[4];
        piping_va[4] <= piping_va[3];
        piping_va[3] <= piping_va[2];
        piping_va[2] <= piping_va[1];
        piping_va[1] <= piping_va[0];
        piping_va[0] <= inter_piping_va;

        piping_pa[5] <= piping_pa[4];
        piping_pa[4] <= piping_pa[3];
        piping_pa[3] <= piping_pa[2];
        piping_pa[2] <= piping_pa[1];
        piping_pa[1] <= piping_pa[0];
        piping_pa[0] <= inter_piping_pa;  // {SADDR{1'bz}};


        piping_pcid[5] <= piping_pcid[4];
        piping_pcid[4] <= piping_pcid[3];
        piping_pcid[3] <= piping_pcid[2];
        piping_pcid[2] <= piping_pcid[1];
        piping_pcid[1] <= piping_pcid[0];
        piping_pcid[0] <= inter_piping_pcid;

        piping_ta[5] <= piping_ta[4];
        piping_ta[4] <= piping_ta[3];
        piping_ta[3] <= piping_ta[2];
        piping_ta[2] <= piping_ta[1];
        piping_ta[1] <= piping_ta[0];
        piping_ta[0] <= {SADDR{1'bz}};
    end

endmodule