`include "inc/state.v"

module MMU
#(
    parameter SADDR=64,
    parameter SPCID=12
)
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

    wire dtlb_hit,  itlb_hit,  stlb_hit,
         dtlb_miss, itlb_miss, stlb_miss,
         judged_dtlb_miss;

    wire [63:0] stat_hit;
    wire [63:0] stat_miss;
    wire [63:0] stat_prefetch;

    reg tlb_insert;
    reg stlb_insert;
    reg [63:0] pa;
    reg ctrl = 1'b0;


    reg     [SADDR-1:0] dtlb_req_va     = {SADDR{1'b0}};
    reg     [SPCID-1:0] dtlb_req_pcid   = {SADDR{1'b0}};
    wire    [SADDR-1:0] dtlb_req_ta;
    reg     [`STATE_RANGE] dtlb_state   = {{5{1'b0}}, 1'b0};

    reg     [SADDR-1:0] itlb_req_va     = {SADDR{1'b0}};
    reg     [SPCID-1:0] itlb_req_pcid   = {SADDR{1'b0}};
    wire    [SADDR-1:0] itlb_req_ta;
    reg     [`STATE_RANGE] itlb_state   = {{6{1'b0}}};

    wire  [SADDR-1:0] stlb_req_ta;
    reg [`STATE_RANGE] stlb_state = {{5{1'b0}}, 1'b0};

    TLB dtlb(// inputs
            .clk(clk), .state(dtlb_state), .req_va(dtlb_req_va), .req_pcid(dtlb_req_pcid),
            .insert_va(stlb_piping_va[3]), .insert_pa(stlb_piping_pa[3]), .insert_pcid(stlb_piping_pcid[3]),
            // outputs
            .req_ta(dtlb_req_ta), .hit(dtlb_hit), .miss(dtlb_miss));

    TLB itlb(// inputs
            .clk(clk), .state(itlb_state), .req_va(itlb_req_va), .req_pcid(itlb_req_pcid),
            .insert_va(stlb_piping_va[3]), .insert_pa(stlb_piping_pa[3]), .insert_pcid(stlb_piping_pcid[3]),
            // outputs
            .req_ta(itlb_req_ta), .hit(itlb_hit), .miss(itlb_miss));

    STLB stlb(// inputs
              .clk(clk),
              .state_bank0(stlb_state), .req_va_bank0(stlb_piping_va[1]), .req_pcid_bank0(stlb_piping_pcid[1]),
              .insert_va_bank0(stlb_piping_va[3]), .insert_pa_bank0(stlb_piping_pa[3]), .insert_pcid_bank0(stlb_piping_pcid[3]),
              //outputs
              .req_ta_bank0(stlb_req_ta), .hit_bank0(stlb_hit), .miss_bank0(stlb_miss));

    PMU pmu(.clk(clk),
            .dtlb_hit(dtlb_hit), .dtlb_miss(judged_dtlb_miss), .dtlb_insert(dtlb_state`insert_bit),
            .itlb_hit(itlb_hit), .itlb_miss(itlb_miss), .itlb_insert(itlb_state`insert_bit),
            .stlb_hit(stlb_hit), .stlb_miss(stlb_miss), .stlb_prefetch(prefetch_stlb), .stlb_insert(stlb_state`insert_bit));

/********************************************************************
                             PIPELINE MACHINE
********************************************************************/

    reg [SADDR-1:0] stlb_piping_va   [5:0];      // virtual address
    reg [SADDR-1:0] stlb_piping_pa   [5:0];      // physical address
    reg [SPCID-1:0] stlb_piping_pcid [5:0];      // process-context identifier
    reg [3:1] piping_marker;                     // iTLB or dTLB info

    reg [SADDR-1:0] incoming_dtlb_va;
    wire [SADDR-1:0] incoming_dtlb_pa = incoming_dtlb_va;
    reg [SPCID-1:0] incoming_dtlb_pcid = 0;

    reg [SADDR-1:0] incoming_itlb_va;
    wire [SADDR-1:0] incoming_itlb_pa = incoming_itlb_va;
    wire [SPCID-1:0] incoming_itlb_pcid = 0;

    reg [SADDR-1:0] prefetching_stlb_va;
    wire [SADDR-1:0] prefetching_stlb_pa = prefetching_stlb_va;
    reg [SPCID-1:0] prefetching_stlb_pcid = 0;

    reg prefetch_stlb;

    wire [SADDR-1:0] itlb_ta = (dtlb_hit)? dtlb_req_ta: {SADDR{1'bx}};
    wire [SADDR-1:0] dtlb_ta = (itlb_hit)? itlb_req_ta: {SADDR{1'bx}};

    reg dtlb_req;
    reg itlb_req;

/* verilator lint_off STMTDLY */
    initial begin

    incoming_dtlb_va = 64'h0;
    incoming_itlb_va = 64'h0;
    dtlb_req = 1;
    itlb_req = 1;

    prefetch_stlb = 1'b1;
    prefetching_stlb_va = 64'hd1ffffffffffffff;

    #2
    dtlb_req = 0;
    itlb_req = 0;
    prefetching_stlb_va = 64'he1ffffffffffffff;

    #2
    prefetch_stlb = 1'b0;
    incoming_dtlb_va = 64'hd1ffffffffffffff;
    incoming_itlb_va = 64'he1ffffffffffffff;
    dtlb_req = 1;
    itlb_req = 1;

    #2
    dtlb_req = 0;
    itlb_req = 0;

    #4 // double insert from L2 to L1

    #2
    incoming_dtlb_va = 64'hd1ffffffffffffff;
    incoming_itlb_va = 64'he1ffffffffffffff;
    dtlb_req = 1;
    itlb_req = 1;

    #2
    dtlb_req = 0;
    itlb_req = 0;

    #2
    incoming_dtlb_va = 64'hd1ffffffffffffff;
    incoming_itlb_va = 64'he1ffffffffffffff;
    dtlb_req = 1;
    itlb_req = 1;

    #2
    incoming_dtlb_va = 64'hd2ffffffffffffff;
    incoming_itlb_va = 64'he2ffffffffffffff;

    #2
    dtlb_req = 0;
    itlb_req = 0;

    #4 // double insert to L1, L2

    #2
    incoming_itlb_va = 64'he2ffffffffffffff;
    itlb_req = 1;

    #2
    incoming_dtlb_va = 64'hd2ffffffffffffff;
    itlb_req = 0;
    dtlb_req = 1;

    #2
    dtlb_req = 0;
    itlb_req = 0;
    end
/* verilator lint_off STMTDLY */

    reg [SADDR-1:0] dtlb_pre_pipe_pa;
    reg [SADDR-1:0] itlb_pre_pipe_pa;

    wire dtlb_itlb_miss_conflict = (itlb_miss & dtlb_miss)? 1'b1 : 1'b0;
    wire stop_itlb_miss = (itlb_miss & prefetch_stlb)? 1'b1 : 1'b0;
    wire stop_dtlb_miss = (dtlb_miss & prefetch_stlb)? 1'b1 : 1'b0;
    assign judged_dtlb_miss = dtlb_miss & ~(itlb_miss & dtlb_miss);

    always @(negedge clk) begin

        // -------------- iTLB & dTLB STATE PIPELINE --------------
        $display("dreq - %b, ireq - %b, conf - %b, - prefetch conflict %b", dtlb_req, itlb_req, dtlb_itlb_miss_conflict, stop_dtlb_miss);
        if (dtlb_req || dtlb_itlb_miss_conflict || stop_dtlb_miss) begin
            dtlb_state`req_bit <= 1'b1;
        end else if (dtlb_hit || dtlb_miss) begin
            dtlb_state`req_bit <= 1'b0;
        end

        if (itlb_req || stop_itlb_miss) begin
            itlb_state`req_bit <= 1'b1;
        end else if (itlb_hit || itlb_miss) begin
            itlb_state`req_bit <= 1'b0;
        end

        if (~prefetch_stlb) begin
            if (~itlb_miss) begin
                if (dtlb_miss) begin
                    dtlb_state`miss_bit <= 1'b1;
                end else if (dtlb_state`miss_bit == 1'b1) begin
                    dtlb_state`miss_bit <= 1'b0;
                end
            end

            if (itlb_miss) begin
                itlb_state`miss_bit <= 1'b1;
            end else if (itlb_state`miss_bit == 1'b1) begin
                itlb_state`miss_bit <= 1'b0;
            end

            // -------------- INSERT RESET --------------
            if (dtlb_state`insert_bit == 1'b1 && stlb_state`miss_bit == 1'b0) begin
                dtlb_state`insert_bit <= 1'b0;
            end

            if (itlb_state`insert_bit == 1'b1 && stlb_state`miss_bit == 1'b0) begin
                itlb_state`insert_bit <= 1'b0;
            end

            // -------------- STLB STATE PIPELINE --------------
            if (dtlb_miss || itlb_miss) begin
                stlb_state`req_bit <= 1'b1;
            end else if (stlb_hit || stlb_miss) begin
                stlb_state`req_bit <= 1'b0;
            end

            if (stlb_state`insert_bit == 1'b1) begin
                stlb_state`insert_bit <= 1'b0;
            end

            if (stlb_hit) begin
                ta <= dtlb_req_ta;

                // if (piping_marker[1]) begin
                //     itlb_state`insert_bit  <= 1'b1;
                // end else begin
                //     dtlb_state`insert_bit  <= 1'b1;
                // end
            end

            // TODO: trigger dtlb and itlb insertions
            if (stlb_state`miss_bit == 1'b1) begin
                stlb_state`insert_bit <= 1'b1;

                if (piping_marker[2]) begin
                    itlb_state`insert_bit  <= 1'b1;
                end else begin
                    dtlb_state`insert_bit  <= 1'b1;
                end
            end

            if (stlb_miss) begin
                stlb_state`miss_bit <= 1'b1;
            end else if (stlb_state`miss_bit == 1'b1) begin
                stlb_state`miss_bit <= 1'b0;
            end

            // -------------- DATA PIPING --------------
            piping_marker <= piping_marker << 1'b1;
            if (itlb_miss) begin
                stlb_piping_va[1]   <= itlb_req_va;
                stlb_piping_pa[1]   <= itlb_pre_pipe_pa;
                stlb_piping_pcid[1] <= itlb_req_pcid;
                piping_marker[1]    <= 1'b1;
            end else begin
                stlb_piping_va[1]   <= dtlb_req_va;
                stlb_piping_pa[1]   <= dtlb_pre_pipe_pa;
                stlb_piping_pcid[1] <= dtlb_req_pcid;
                piping_marker[1]    <= 1'b0;
            end

            itlb_req_va         <= incoming_itlb_va;
            itlb_pre_pipe_pa    <= incoming_itlb_pa;
            itlb_req_pcid       <= incoming_itlb_pcid;
            //------------------------------------------
            if (~dtlb_itlb_miss_conflict) begin
                dtlb_req_va         <= incoming_dtlb_va;
                dtlb_pre_pipe_pa    <= incoming_dtlb_pa;
                dtlb_req_pcid       <= incoming_dtlb_pcid;
            end

            // if (stlb_hit) begin
            //     stlb_piping_va[3] <= stlb_piping_va[1];
            //     //------------------------------------------
            //     stlb_piping_pa[3] <= stlb_piping_pa[1];
            //     //------------------------------------------
            //     stlb_piping_pcid[3] <= stlb_piping_pcid[1];
            // end
            // else begin
            //------------------------------------------
            stlb_piping_va[3] <= stlb_piping_va[2];
            stlb_piping_va[2] <= stlb_piping_va[1];
            //------------------------------------------
            stlb_piping_pa[3] <= stlb_piping_pa[2];
            stlb_piping_pa[2] <= stlb_piping_pa[1];
            //------------------------------------------
            stlb_piping_pcid[3] <= stlb_piping_pcid[2];
            stlb_piping_pcid[2] <= stlb_piping_pcid[1];
            // end
            // stlb_piping_ta[3] <= stlb_piping_ta[2];
            // stlb_piping_ta[2] <= stlb_piping_ta[1];
            // stlb_piping_ta[1] <= stlb_piping_ta[0];
            // stlb_piping_ta[0] <= {SADDR{1'bz}};
        end else begin
            dtlb_state`insert_bit <= 1'b0;
            itlb_state`insert_bit <= 1'b0;
            stlb_state`insert_bit <= 1'b1;
            //------------------------------------------
            stlb_piping_va[3]   <= prefetching_stlb_va;
            stlb_piping_pa[3]   <= prefetching_stlb_pa;
            stlb_piping_pcid[3] <= prefetching_stlb_pcid;
            //------------------------------------------
            if (~dtlb_itlb_miss_conflict) begin
                if (~dtlb_miss) begin
                    dtlb_req_va         <= incoming_dtlb_va;
                    dtlb_pre_pipe_pa    <= incoming_dtlb_pa;
                    dtlb_req_pcid       <= incoming_dtlb_pcid;
                end

                if (~itlb_miss) begin
                    itlb_req_va         <= incoming_itlb_va;
                    itlb_pre_pipe_pa    <= incoming_itlb_pa;
                    itlb_req_pcid       <= incoming_itlb_pcid;
                end
            end
        end

    end

endmodule