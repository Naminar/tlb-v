/********************************************************************
                            PLRU tree
*********************************************************************

      0b  
    /    \
  1b      2b
 /  \    /  \
3b   4b 5b   6b

if nb is 1 it direct to the right, else(0) to the left. 

In memory representation:
|0b|1b|2b|3b|4b|5b|6b|

To go to the next bit in tree representation use ind*2 + 1 or 2, 1 - to the left
and 2 - to the right.

For each hit or new insertion in cache there's a need to rebuild plru-tree. 
*/ 

//state ranege
`define STATE_R 2:0
`define STATE                    \
parameter state_waiting = 3'b000;\
parameter state_req     = 3'b001;\
parameter state_miss    = 3'b010;\
parameter state_insert  = 3'b100;\
parameter state_shutdown= 3'b101;
// parameter state_write   = 3'b011;\

module cache 
#(
    parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=8    // way number
)
(
    input clk,
    input  shutdown,            // clear tlb
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
        new_plru = (old_plru & !mask) | (mask & value);
    end
endfunction 

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)];

// parameter state_waiting = 3'b000;
// parameter state_req     = 3'b001;
// parameter state_miss    = 3'b010;
// parameter state_write   = 3'b011;
// parameter state_insert  = 3'b100;
`STATE 

reg [`STATE_R] state = state_waiting;

reg [NWAY-2:0] plru [NSET-1:0];    

reg [SADDR-1:0] prev_addr = 0;
reg [SPCID-1:0] prev_pcid = 0;

integer a;
initial begin
    for (a = 0; a < NWAY; a = a + 1)
        plru[a] = 0;
end

/********************************************************************
                             STATE MACHINE
********************************************************************/
wire [NWAY-1:0] way_hit;
wire [SADDR-SPAGE-1:0] way_ta [NWAY-1:0];
reg [NWAY-1:0] write = 0;

genvar ind; 
generate
    for (ind = 0; ind < NWAY; ind = ind + 1) begin: ways
        way  w();
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
            write <= 0;
        end
        
        state_req: begin
            ta[SPAGE-1:0] <= local_addr;
            hit <= 1'b1;
            state <= state_waiting;
            // ways[0].w.hit != 0
            if(ways[0].w.tag[set] == tag && ways[0].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b0;
                // plru[set][3] = 1'b0;
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0000000);
                ta[SADDR-1:SPAGE] <= ways[0].w.pa[set];
            end else if(ways[1].w.tag[set] == tag && ways[1].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b0;
                // plru[set][3] = 1'b1;
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0001000);
                ta[SADDR-1:SPAGE] <= ways[1].w.pa[set];
            end else if(ways[2].w.tag[set] == tag && ways[2].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b1;
                // plru[set][4] = 1'b0;
                plru[set] = new_plru(plru[set], 7'b0001011, 7'b0000010);
                ta[SADDR-1:SPAGE] <= ways[2].w.pa[set];
            end else if(ways[3].w.tag[set] == tag && ways[3].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b1;
                // plru[set][4] = 1'b1;
                plru[set] = new_plru(plru[set], 7'b0010011, 7'b0010010);
                ta[SADDR-1:SPAGE] <= ways[3].w.pa[set];
            end else if(ways[4].w.tag[set] == tag && ways[4].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b0;
                // plru[set][5] = 1'b0;
                plru[set] = new_plru(plru[set], 7'b0100101, 7'b0000001);
                ta[SADDR-1:SPAGE] <= ways[4].w.pa[set];
            end else if(ways[5].w.tag[set] == tag && ways[5].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b0;
                // plru[set][5] = 1'b1;
                plru[set] = new_plru(plru[set], 7'b0100101, 7'b0100001);
                ta[SADDR-1:SPAGE] <= ways[5].w.pa[set];
            end else if(ways[6].w.tag[set] == tag && ways[6].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b1;
                // plru[set][6] = 1'b0;
                plru[set] = new_plru(plru[set], 7'b1000101, 7'b0000101);
                ta[SADDR-1:SPAGE] <= ways[6].w.pa[set];
            end else if(ways[7].w.tag[set] == tag && ways[7].w.pcid[set] == pcid) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b1;
                // plru[set][6] = 1'b1;
                plru[set] = new_plru(plru[set], 7'b1000101, 7'b1000101);
                ta[SADDR-1:SPAGE] <= ways[7].w.pa[set];
            end else begin
                miss <= 1'b1;
                hit <= 1'b0;
                state <= state_miss;
            end
        // end state_req
        end
        
        state_miss: begin
            miss <= 1'b1;
            // end plru tree
            ta[SADDR-1:0] <= {pa[SADDR-1:SPAGE], local_addr};
            state <= state_insert;
        end

        state_insert: begin
            if (plru[set][0]) begin
                plru[set][0] = !plru[set][0];
                if (plru[set][1]) begin
                    plru[set][1] = !plru[set][1];
                    plru[set][3] = !plru[set][3];
                    
                    if (plru[set][3]) begin
                        ways[1].w.tag[set]  <= tag;
                        ways[1].w.pcid[set] <= pcid;
                        ways[1].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        // write[0] = 1'b1;
                        ways[0].w.tag[set]  <= tag;
                        ways[0].w.pcid[set] <= pcid;
                        ways[0].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[set][1] = !plru[set][1];
                    plru[set][4] = !plru[set][4];
                    
                    if (plru[set][4]) begin
                        // write[3] = 1'b1;
                        ways[3].w.tag[set]  <= tag;
                        ways[3].w.pcid[set] <= pcid;
                        ways[3].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        // write[2] = 1'b1;
                        ways[2].w.tag[set]  <= tag;
                        ways[2].w.pcid[set] <= pcid;
                        ways[2].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                end
            end else begin
                plru[set][0] = !plru[set][0];
                if (plru[set][2]) begin
                    plru[set][2] = !plru[set][2];
                    plru[set][5] = !plru[set][5];

                    if (plru[set][5]) begin
                        // write[5] = 1'b1;
                        ways[5].w.tag[set]  <= tag;
                        ways[5].w.pcid[set] <= pcid;
                        ways[5].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        // write[4] = 1'b1;
                        ways[4].w.tag[set]  <= tag;
                        ways[4].w.pcid[set] <= pcid;
                        ways[4].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                end else begin
                    plru[set][2] = !plru[set][2];
                    plru[set][6] = !plru[set][6];

                    if (plru[set][6]) begin
                        // write[7] = 1'b1;
                        ways[7].w.tag[set]  <= tag;
                        ways[7].w.pcid[set] <= pcid;
                        ways[7].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                    else begin
                        // write[6] = 1'b1;
                        ways[6].w.tag[set]  <= tag;
                        ways[6].w.pcid[set] <= pcid;
                        ways[6].w.pa[set]   <= pa[SADDR-1:SPAGE];
                    end
                end
            end
            state <= state_waiting; 
        end

        state_shutdown: begin: shutdown_tlb
            integer  s_ind;
            for (s_ind = 0; s_ind < NSET; s_ind = s_ind + 1) begin
                ways[0].w.tag[s_ind]  <= 0;
                ways[0].w.pcid[s_ind] <= 0;
                ways[0].w.pa[s_ind]   <= 0; 
                
                ways[1].w.tag[s_ind]  <= 0;
                ways[1].w.pcid[s_ind] <= 0;
                ways[1].w.pa[s_ind]   <= 0; 

                ways[2].w.tag[s_ind]  <= 0;
                ways[2].w.pcid[s_ind] <= 0;
                ways[2].w.pa[s_ind]   <= 0; 

                ways[3].w.tag[s_ind]  <= 0;
                ways[3].w.pcid[s_ind] <= 0;
                ways[3].w.pa[s_ind]   <= 0; 

                ways[4].w.tag[s_ind]  <= 0;
                ways[4].w.pcid[s_ind] <= 0;
                ways[4].w.pa[s_ind]   <= 0; 

                ways[5].w.tag[s_ind]  <= 0;
                ways[5].w.pcid[s_ind] <= 0;
                ways[5].w.pa[s_ind]   <= 0; 

                ways[6].w.tag[s_ind]  <= 0;
                ways[6].w.pcid[s_ind] <= 0;
                ways[6].w.pa[s_ind]   <= 0; 

                ways[7].w.tag[s_ind]  <= 0;
                ways[7].w.pcid[s_ind] <= 0;
                ways[7].w.pa[s_ind]   <= 0;  
            end
            state <= state_waiting;
        end
        default: ;
    endcase
end
endmodule