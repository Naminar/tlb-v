`include "inc/range.v"
`include "inc/state.v"

module TLB 
#(
    parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=8    // way number
)
(
    input clk,
    input [`STATE_R] state,
    // input shutdown,                     //   clear tlb
    // input insert,                       //   forcibly insert PTE
    input  [SADDR-1:0] req_va,        // virtual address
    input  [SPCID-1:0] req_pcid,      // process-context identifier
    input  [SADDR-1:0] insert_va,        // virtual address
    input  [SADDR-1:0] insert_pa,        // physical address
    input  [SPCID-1:0] insert_pcid,      // process-context identifier
    output reg [SADDR-1:0] req_ta,    // translated address
    output reg hit,
    output reg miss
);

function [6:0] new_plru(input [6:0] old_plru, input [6:0] mask, input [6:0] value);
    begin 
        new_plru = (old_plru & ~mask) | (mask & value);
    end
endfunction 

`STATE

wire [SPAGE-1:0]                    req_local_addr      = req_va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             req_set             = req_va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] req_tag             = req_va[SADDR-1:SPAGE+$clog2(NSET)];
wire [SPAGE-1:0]                    insert_local_addr   = insert_va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             insert_set          = insert_va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] insert_tag          = insert_va[SADDR-1:SPAGE+$clog2(NSET)];

// reg [`STATE_R] state;
reg [NWAY-2:0] plru [NSET-1:0];    
reg [SADDR-1:0] prev_addr = 0;
reg [SPCID-1:0] prev_pcid = 0;
// include valid bit, but didn't used.
reg [SADDR-$clog2(NSET)-SPAGE+SPCID+SADDR-SPAGE:0] entries [NSET-1:0][NWAY-1:0];

// assign out_state = state;

initial begin: init_plru_and_entries
    integer  w_ind, s_ind, a;
    hit = 0;
    miss = 0;
    // state[`STATE_R] = state_waiting;

    for (a = 0; a < NSET; a = a + 1)
        plru[a] = 0;
    
    for (s_ind = 0; s_ind < NSET; s_ind = s_ind + 1) begin
        for (w_ind = 0; w_ind < NWAY; w_ind = w_ind + 1) begin
            entries[s_ind][w_ind]`VALIDE_BIT    = 0;
            entries[s_ind][w_ind]`TAG_RANGE     = 0;
            entries[s_ind][w_ind]`PCID_RANGE    = 0;
            entries[s_ind][w_ind]`PA_RANGE      = 0; 
        end
    end
end

/********************************************************************
                             PIPELINE MACHINE
********************************************************************/
genvar s_ind;
generate
    for (s_ind = 0; s_ind < NSET; s_ind = s_ind + 1) begin: clear
        always @(posedge clk) begin: shutdown_stlb
            if (state == state_shutdown) begin: shutdown_tlb
                integer  w_ind;
                for (w_ind = 0; w_ind < NWAY; w_ind = w_ind + 1) begin
                    entries[s_ind][w_ind]`VALIDE_BIT    <= 0;
                    entries[s_ind][w_ind]`TAG_RANGE     <= 0;
                    entries[s_ind][w_ind]`PCID_RANGE    <= 0;
                    entries[s_ind][w_ind]`PA_RANGE      <= 0; 
                end
            end
        end
    end
endgenerate 

always @(posedge clk) begin
    // if (state != state_shutdown && ( prev_addr != va || pcid != prev_pcid)) begin
    //    state <= state_req;
    //    prev_addr <= va;
    //    prev_pcid <= pcid;
    // end else if (shutdown != 0) begin
    //     state <= state_shutdown;
    // end else if (insert != 0) begin
    //     state <= state_insert;
    // end

    // case (state)

        if ((state & state_req) == state_waiting) begin
            miss <= 0;
            hit  <= 0;
        end
        
        if ((state & state_req) == state_req) begin
            req_ta[SPAGE-1:0] <= req_local_addr;
            hit <= 1'b1;
            // state <= state_waiting;

            if(entries[req_set][0]`TAG_RANGE == req_tag && entries[req_set][0]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0001011, 7'b0000000);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][0]`PA_RANGE;

            end else if(entries[req_set][1]`TAG_RANGE == req_tag && entries[req_set][1]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0001011, 7'b0001000);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][1]`PA_RANGE;

            end else if(entries[req_set][2]`TAG_RANGE == req_tag && entries[req_set][2]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0001011, 7'b0000010);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][2]`PA_RANGE;

            end else if(entries[req_set][3]`TAG_RANGE == req_tag && entries[req_set][3]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0010011, 7'b0010010);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][3]`PA_RANGE;

            end else if(entries[req_set][4]`TAG_RANGE == req_tag && entries[req_set][4]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0100101, 7'b0000001);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][4]`PA_RANGE;

            end else if(entries[req_set][5]`TAG_RANGE == req_tag && entries[req_set][5]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b0100101, 7'b0100001);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][5]`PA_RANGE;

            end else if(entries[req_set][6]`TAG_RANGE == req_tag && entries[req_set][6]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b1000101, 7'b0000101);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][6]`PA_RANGE;

            end else if(entries[req_set][7]`TAG_RANGE == req_tag && entries[req_set][7]`PCID_RANGE == req_pcid) begin
                plru[req_set] = new_plru(plru[req_set], 7'b1000101, 7'b1000101);
                req_ta[SADDR-1:SPAGE] <= entries[req_set][7]`PA_RANGE;
            end else begin
                miss <= 1'b1;
                hit <= 1'b0;
                // state <= state_miss;
                // state <= state & ~state_req;
                // state <= state | state_miss;
            end
        // end state_req
        end
        
        if ((state & state_miss) == state_miss) begin
            miss <= 1'b0;
            // state <= state_waiting;
        end

        if ((state & state_insert) == state_insert) begin
            if (plru[insert_set][0]) begin
                plru[insert_set][0] = !plru[insert_set][0];
                if (plru[insert_set][1]) begin
                    plru[insert_set][1] = !plru[insert_set][1];
                    plru[insert_set][3] = !plru[insert_set][3];
                    
                    if (plru[insert_set][3]) begin
                        entries[insert_set][1]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][1]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][1]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[insert_set][0]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][0]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][0]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[insert_set][1] = !plru[insert_set][1];
                    plru[insert_set][4] = !plru[insert_set][4];
                    
                    if (plru[insert_set][4]) begin
                        entries[insert_set][3]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][3]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][3]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[insert_set][2]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][2]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][2]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                end
            end else begin
                plru[insert_set][0] = !plru[insert_set][0];
                if (plru[insert_set][2]) begin
                    plru[insert_set][2] = !plru[insert_set][2];
                    plru[insert_set][5] = !plru[insert_set][5];

                    if (plru[insert_set][5]) begin
                        entries[insert_set][5]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][5]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][5]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[insert_set][4]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][4]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][4]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[insert_set][2] = !plru[insert_set][2];
                    plru[insert_set][6] = !plru[insert_set][6];

                    if (plru[insert_set][6]) begin
                        entries[insert_set][7]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][7]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][7]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[insert_set][6]`TAG_RANGE  <= insert_tag;
                        entries[insert_set][6]`PCID_RANGE <= insert_pcid;
                        entries[insert_set][6]`PA_RANGE   <= insert_pa[SADDR-1:SPAGE];
                    end
                end
            end
            // state <= state_waiting;
        // end state_insert
        end

        if ((state & state_shutdown) == state_shutdown) begin
            // another always block: line 66
            // state <= state_waiting;
        // end state_shutdown
        end
        // default: ;
    // endcase
end
endmodule