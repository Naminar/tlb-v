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
    // input  shutdown,
    input  [SADDR-1:0] va, // virtual address
    input  [SADDR-1:0] pa, // physical address
    input  [SPCID-1:0] pcid, // process-context identifier
    output reg [SADDR-1:0] ta, // translated address
    output reg hit,
    output reg miss
);

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)];

parameter state_waiting = 2'b00;
parameter state_req     = 2'b01;
parameter state_miss    = 2'b10;

reg [1:0] state = state_waiting;

reg [NWAY-2:0] plru [NSET-1:0] [NWAY-1:0];

/********************************************************************
                            TAG-PCID-PHYSICAL ADDRESS
********************************************************************/

reg [SADDR-$clog2(NWAY)-1:0]    tag_way0  [NSET-1:0]; // belongs to a va
reg [SPCID-1:0]                 pcid_way0 [NSET-1:0]; // belongs to a va
reg [SADDR-SPAGE-1:0]           pa_way0   [NSET-1:0]; // pa without local address

reg [SADDR-$clog2(NWAY)-1:0]    tag_way1  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way1 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way1   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way2  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way2 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way2   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way3  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way3 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way3   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way4  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way4 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way4   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way5  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way5 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way5   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way6  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way6 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way6   [NSET-1:0];

reg [SADDR-$clog2(NWAY)-1:0]    tag_way7  [NSET-1:0];
reg [SPCID-1:0]                 pcid_way7 [NSET-1:0];
reg [SADDR-SPAGE-1:0]           pa_way7   [NSET-1:0];


initial begin: init
    integer  i;
    integer a;
    for (i = 0; i < NSET; i = i + 1) begin
        for (a=0; a < NWAY; a = a +1 )
            plru[i][a] = 0;
        
        pa_way0[i]   = 0;
        pa_way1[i]   = 0;
        pa_way2[i]   = 0;
        pa_way3[i]   = 0;
        pa_way4[i]   = 0;
        pa_way5[i]   = 0;
        pa_way6[i]   = 0;       
        pa_way7[i]   = 0;   

        pcid_way0[i] = 0;
        pcid_way1[i] = 0;
        pcid_way2[i] = 0;
        pcid_way3[i] = 0;
        pcid_way4[i] = 0;
        pcid_way5[i] = 0;
        pcid_way6[i] = 0;
        pcid_way7[i] = 0;

        tag_way0[i]  = 0;
        tag_way1[i]  = 0;
        tag_way2[i]  = 0;
        tag_way3[i]  = 0;
        tag_way4[i]  = 0;
        tag_way5[i]  = 0;
        tag_way6[i]  = 0;
        tag_way7[i]  = 0;
    end     


end     

reg [SADDR-1:0] prev_addr = 0;

always @(posedge clk) begin
    if (prev_addr != va) begin
       state <= state_req;
       prev_addr <= va;
    end
end

/********************************************************************
                             STATE MACHINE
********************************************************************/

always @(posedge clk) begin
    
    case (state)
        state_waiting: begin
            miss <= 0;
            hit  <= 0;
        end
        
        state_req: begin
            ta[SPAGE-1:0] <= local_addr;
            hit <= 1'b1;
            state <= state_waiting;

            if(tag_way0[set] == tag && pcid_way0[set] == pcid) begin
                
                ta[SADDR-1:SPAGE] <= pa_way0[set];
                // update tree 
                plru[set][0] = 1'b0;
                plru[set][1] = 1'b0;
                plru[set][3] = 1'b0;

            end if(tag_way1[set] == tag && pcid_way1[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way1[set];
                // update tree 
                plru[set][0] = 1'b0;
                plru[set][1] = 1'b0;
                plru[set][3] = 1'b1;
                
            end if(tag_way2[set] == tag && pcid_way2[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way2[set];
                // update tree
                plru[set][0] = 1'b0;
                plru[set][1] = 1'b1;
                plru[set][4] = 1'b0;

            end if(tag_way3[set] == tag && pcid_way3[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way3[set];
                // update tree
                plru[set][0] = 1'b0;
                plru[set][1] = 1'b1;
                plru[set][4] = 1'b1;

            end if(tag_way4[set] == tag && pcid_way4[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way4[set];
                // update tree 
                plru[set][0] = 1'b1;
                plru[set][2] = 1'b0;
                plru[set][5] = 1'b0;

            end if(tag_way5[set] == tag && pcid_way5[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way5[set];
                // update tree 
                plru[set][0] = 1'b1;
                plru[set][2] = 1'b0;
                plru[set][5] = 1'b1;

            end if(tag_way6[set] == tag && pcid_way6[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way6[set];
                // update tree
                plru[set][0] = 1'b1;
                plru[set][2] = 1'b1;
                plru[set][6] = 1'b0;

            end if(tag_way7[set] == tag && pcid_way7[set] == pcid) begin
                ta[SADDR-1:SPAGE] <= pa_way7[set];
                // update tree 
                plru[set][0] = 1'b1;
                plru[set][2] = 1'b1;
                plru[set][6] = 1'b1;
                
            end else begin
                hit <= 1'b0;
                state <= state_miss;
            end
        // end state_req
        end
        
        state_miss: begin
            miss <= 1'b1;
            if (plru[set][0]) begin
                plru[set][0] = !plru[set][0];
                if (plru[set][1]) begin
                    plru[set][1] = !plru[set][1];
                    plru[set][3] = !plru[set][3];
                    
                    if (plru[set][3]) begin
                        pa_way1[set]   <= pa[SADDR-1:SPAGE];
                        tag_way1[set]  <= tag;
                        pcid_way1[set] <= pcid;
                    end
                    else begin
                        pa_way0[set]   <= pa[SADDR-1:SPAGE];
                        tag_way0[set]  <= tag;
                        pcid_way0[set] <= pcid;
                    end
                end else begin
                    plru[set][1] = !plru[set][1];
                    plru[set][4] = !plru[set][4];
                    
                    if (plru[set][4]) begin
                        pa_way3[set]   <= pa[SADDR-1:SPAGE];
                        tag_way3[set]  <= tag;
                        pcid_way3[set] <= pcid;
                    end
                    else begin
                        pa_way2[set]   <= pa[SADDR-1:SPAGE];
                        tag_way2[set]  <= tag;
                        pcid_way2[set] <= pcid;
                    end
                end
            end else begin
                plru[set][0] = !plru[set][0];
                if (plru[set][2]) begin
                    plru[set][2] = !plru[set][2];
                    plru[set][5] = !plru[set][5];

                    if (plru[set][5]) begin
                        pa_way5[set]   <= pa[SADDR-1:SPAGE];
                        tag_way5[set]  <= tag;
                        pcid_way5[set] <= pcid;
                    end
                    else begin
                        pa_way4[set]   <= pa[SADDR-1:SPAGE];
                        tag_way4[set]  <= tag;
                        pcid_way4[set] <= pcid;
                    end
                end else begin
                    plru[set][2] = !plru[set][2];
                    plru[set][6] = !plru[set][6];

                    if (plru[set][6]) begin
                        pa_way7[set]   <= pa[SADDR-1:SPAGE];
                        tag_way7[set]  <= tag;
                        pcid_way7[set] <= pcid;
                    end
                    else begin
                        pa_way6[set]   <= pa[SADDR-1:SPAGE];
                        tag_way6[set]  <= tag;
                        pcid_way6[set] <= pcid;
                    end
                end
            end
            // end plru tree

            ta[SADDR-1:0] <= {pa[SADDR-1:SPAGE], local_addr};
            state <= state_waiting;
        end
        default: ;
    endcase
end
endmodule