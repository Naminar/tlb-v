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
    input shutdown,             // clear tlb
    input insert,               // forcibly insert PTE
    input  [SADDR-1:0] va,      // virtual address
    input  [SADDR-1:0] pa,      // physical address
    input  [SPCID-1:0] pcid,    // process-context identifier
    output reg [SADDR-1:0] ta,  // translated address
    output reg hit,
    output reg miss
);

function [6:0] new_plru(input [6:0] old_plru, input [6:0] mask, input [6:0] value);
    begin 
        new_plru = (old_plru & ~mask) | (mask & value);
    end
endfunction 

`STATE

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)];

reg [`STATE_R] state;
reg [NWAY-2:0] plru [NSET-1:0];    
reg [SADDR-1:0] prev_addr = 0;
reg [SPCID-1:0] prev_pcid = 0;
// include valid bit, but didn't used.
reg [SADDR-$clog2(NSET)-SPAGE+SPCID+SADDR-SPAGE:0] entries [NSET-1:0][NWAY-1:0];

initial begin: init_plru_and_entries
    integer  w_ind, s_ind, a;
    state[`STATE_R] = state_waiting;

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
                             STATE MACHINE
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
    if (state != state_shutdown && ( prev_addr != va || pcid != prev_pcid)) begin
       state <= state_req;
       prev_addr <= va;
       prev_pcid <= pcid;
    end else if (shutdown != 0) begin
        state <= state_shutdown;
    end else if (insert != 0) begin
        state <= state_insert;
    end

    case (state)
        state_waiting: begin
            miss <= 0;
            hit  <= 0;
        end
        
        state_req: begin
            ta[SPAGE-1:0] <= local_addr;
            hit <= 1'b1;
            state <= state_waiting;

            if(entries[set][0]`TAG_RANGE == tag && entries[set][0]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0000000);
                ta[SADDR-1:SPAGE] <= entries[set][0]`PA_RANGE;

            end else if(entries[set][1]`TAG_RANGE == tag && entries[set][1]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0001000);
                ta[SADDR-1:SPAGE] <= entries[set][1]`PA_RANGE;

            end else if(entries[set][2]`TAG_RANGE == tag && entries[set][2]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0000010);
                ta[SADDR-1:SPAGE] <= entries[set][2]`PA_RANGE;

            end else if(entries[set][3]`TAG_RANGE == tag && entries[set][3]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0010011, 7'b0010010);
                ta[SADDR-1:SPAGE] <= entries[set][3]`PA_RANGE;

            end else if(entries[set][4]`TAG_RANGE == tag && entries[set][4]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0100101, 7'b0000001);
                ta[SADDR-1:SPAGE] <= entries[set][4]`PA_RANGE;

            end else if(entries[set][5]`TAG_RANGE == tag && entries[set][5]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b0100101, 7'b0100001);
                ta[SADDR-1:SPAGE] <= entries[set][5]`PA_RANGE;

            end else if(entries[set][6]`TAG_RANGE == tag && entries[set][6]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b1000101, 7'b0000101);
                ta[SADDR-1:SPAGE] <= entries[set][6]`PA_RANGE;

            end else if(entries[set][7]`TAG_RANGE == tag && entries[set][7]`PCID_RANGE == pcid) begin
                plru[set] = new_plru(plru[set], 7'b1000101, 7'b1000101);
                ta[SADDR-1:SPAGE] <= entries[set][7]`PA_RANGE;
            end else begin
                miss <= 1'b1;
                hit <= 1'b0;
                state <= state_miss;
            end
        // end state_req
        end
        
        state_miss: begin
            miss <= 1'b0;
            state <= state_waiting;
        end

        state_insert: begin
            if (plru[set][0]) begin
                plru[set][0] = !plru[set][0];
                if (plru[set][1]) begin
                    plru[set][1] = !plru[set][1];
                    plru[set][3] = !plru[set][3];
                    
                    if (plru[set][3]) begin
                        entries[set][1]`TAG_RANGE  <= tag;
                        entries[set][1]`PCID_RANGE <= pcid;
                        entries[set][1]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[set][0]`TAG_RANGE  <= tag;
                        entries[set][0]`PCID_RANGE <= pcid;
                        entries[set][0]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[set][1] = !plru[set][1];
                    plru[set][4] = !plru[set][4];
                    
                    if (plru[set][4]) begin
                        entries[set][3]`TAG_RANGE  <= tag;
                        entries[set][3]`PCID_RANGE <= pcid;
                        entries[set][3]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[set][2]`TAG_RANGE  <= tag;
                        entries[set][2]`PCID_RANGE <= pcid;
                        entries[set][2]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                end
            end else begin
                plru[set][0] = !plru[set][0];
                if (plru[set][2]) begin
                    plru[set][2] = !plru[set][2];
                    plru[set][5] = !plru[set][5];

                    if (plru[set][5]) begin
                        entries[set][5]`TAG_RANGE  <= tag;
                        entries[set][5]`PCID_RANGE <= pcid;
                        entries[set][5]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[set][4]`TAG_RANGE  <= tag;
                        entries[set][4]`PCID_RANGE <= pcid;
                        entries[set][4]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[set][2] = !plru[set][2];
                    plru[set][6] = !plru[set][6];

                    if (plru[set][6]) begin
                        entries[set][7]`TAG_RANGE  <= tag;
                        entries[set][7]`PCID_RANGE <= pcid;
                        entries[set][7]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        entries[set][6]`TAG_RANGE  <= tag;
                        entries[set][6]`PCID_RANGE <= pcid;
                        entries[set][6]`PA_RANGE   <= pa[SADDR-1:SPAGE];
                    end
                end
            end
            state <= state_waiting;
        // end state_insert
        end

        state_shutdown: begin
            // another always block: line 66
            state <= state_waiting;
        // end state_shutdown
        end
        default: ;
    endcase
end
endmodule