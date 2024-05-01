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
`define STATE_R 1:0 
`include "log/log2.v"

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
    input  shutdown,
    // input insert,
    input  [SADDR-1:0] va, // virtual address
    input  [SADDR-1:0] pa, // physical address
    input  [SPCID-1:0] pcid, // process-context identifier
    output reg [SADDR-1:0] ta, // translated address
    output reg hit,
    output reg miss
);

function use_mask(input plru, mask, value);
    begin 
        plru = (plru & !mask) | (mask & value);
    end
endfunction 

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)];

parameter state_waiting = 2'b00;
parameter state_req     = 2'b01;
parameter state_miss    = 2'b10;
parameter state_write   = 2'b11;

reg [1:0] state = state_waiting;

reg [NWAY-2:0] plru [NSET-1:0];    

reg [SADDR-1:0] prev_addr = 0;
reg [SPCID-1:0] prev_pcid = 0;

integer a;
initial begin
    for (a = 0; a < NWAY; a = a + 1)
        plru[a] = 0;
end

always @(posedge clk) begin
    if (prev_addr != va || pcid != prev_pcid) begin
       state <= state_req;
       prev_addr <= va;
       prev_pcid <= pcid;
    end
end

/********************************************************************
                             STATE MACHINE
********************************************************************/
wire [NWAY-1:0] way_hit;
wire [SADDR-SPAGE-1:0] way_ta [NWAY-1:0];
reg [NWAY-1:0] write = 0;

// way way_0 (clk, state, set, tag, pcid, ta[], hit[])

genvar ind; 
generate
    for (ind = 0; ind < NWAY; ind = ind + 1) begin: ways
        way  w(clk, state, write[ind], set, tag, pcid, pa[SADDR-1:SPAGE], way_ta[ind], way_hit[ind]);
    end
endgenerate
 

always @(posedge clk) begin
    
    if (shutdown != 0) begin
        state <= state_waiting;
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

            if(way_hit[0] != 0) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b0;
                // plru[set][3] = 1'b0;
                plru[set] <= use_mask(plru[set], 7'b0001011, 7'b0000000);
                ta[SADDR-1:SPAGE] <= way_ta[0];
            end if(way_hit[1] != 0) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b0;
                // plru[set][3] = 1'b1;
                plru[set] <= use_mask(plru[set], 7'b0001011, 7'b0001000);
                ta[SADDR-1:SPAGE] <= way_ta[1];
            end if(way_hit[2] != 0) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b1;
                // plru[set][4] = 1'b0;
                plru[set] <= use_mask(plru[set], 7'b0001011, 7'b0000010);
                ta[SADDR-1:SPAGE] <= way_ta[2];
            end if(way_hit[3] != 0) begin
                // plru[set][0] = 1'b0;
                // plru[set][1] = 1'b1;
                // plru[set][4] = 1'b1;
                plru[set] <= use_mask(plru[set], 7'b0010011, 7'b0010010);
                ta[SADDR-1:SPAGE] <= way_ta[3];
            end if(way_hit[4] != 0) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b0;
                // plru[set][5] = 1'b0;
                plru[set] <= use_mask(plru[set], 7'b0100101, 7'b0000001);
                ta[SADDR-1:SPAGE] <= way_ta[4];
            end if(way_hit[5] != 0) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b0;
                // plru[set][5] = 1'b1;
                plru[set] <= use_mask(plru[set], 7'b0100101, 7'b0100001);
                ta[SADDR-1:SPAGE] <= way_ta[5];
            end if(way_hit[6] != 0) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b1;
                // plru[set][6] = 1'b0;
                plru[set] <= use_mask(plru[set], 7'b1000101, 7'b0000101);
                ta[SADDR-1:SPAGE] <= way_ta[6];
            end if(way_hit[7] != 0) begin
                // plru[set][0] = 1'b1;
                // plru[set][2] = 1'b1;
                // plru[set][6] = 1'b1;
                plru[set] <= use_mask(plru[set], 7'b1000101, 7'b1000101);
                ta[SADDR-1:SPAGE] <= way_ta[7];
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
                        write[1] = 1'b1;
                    end
                    else begin
                        write[0] = 1'b1;
                    end
                end else begin
                    plru[set][1] = !plru[set][1];
                    plru[set][4] = !plru[set][4];
                    
                    if (plru[set][4]) begin
                        write[3] = 1'b1;
                    end
                    else begin
                        write[2] = 1'b1;
                    end
                end
            end else begin
                plru[set][0] = !plru[set][0];
                if (plru[set][2]) begin
                    plru[set][2] = !plru[set][2];
                    plru[set][5] = !plru[set][5];

                    if (plru[set][5]) begin
                        write[5] = 1'b1;
                    end
                    else begin
                        write[4] = 1'b1;
                    end
                end else begin
                    plru[set][2] = !plru[set][2];
                    plru[set][6] = !plru[set][6];

                    if (plru[set][6]) begin
                        write[7] = 1'b1;
                    end
                    else begin
                        write[6] = 1'b1;
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


module way 
#(  parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=8    // way number
)  
(   input clk,
    input [`STATE_R] state,
    input write,
    input [$clog2(NSET)-1:0]             set,
    input [SADDR-1-SPAGE-$clog2(NSET):0] tag,
    input  [SPCID-1:0] pcid,
    input [SADDR-SPAGE-1:0] pa,
    output reg [SADDR-SPAGE-1:0] ta,
    output reg hit = 1'b1
);

    parameter state_waiting = 2'b00;
    parameter state_req     = 2'b01;
    parameter state_miss    = 2'b10;
    parameter state_write   = 2'b11;

    reg [SADDR-$clog2(NWAY)-1:0]    way_tag  [NSET-1:0];
    reg [SPCID-1:0]                 way_pcid [NSET-1:0];
    reg [SADDR-SPAGE-1:0]           way_pa   [NSET-1:0];

    integer i;
    initial begin
        for (i = 0; i < NSET; i = i + 1) begin
            way_pa[i]   = 0;        
            way_pcid[i] = 0;
            way_tag[i]  = 0;
        end        
    end
  
    always @(*) begin
        case (state)
            state_waiting:begin
               hit = 1'b0; 
            end
            state_req: begin
                if(way_tag[set] == tag && way_pcid[set] == pcid) begin
                    hit = 1'b1;
                    ta = way_pa[set];
                end
            end
            state_miss: begin
                if(write != 0) begin
                    way_tag[set] <= tag;
                    way_pcid[set] <= pcid;
                    way_pa[set] <= pa;
                end
            end 
            default:;
        endcase        
    end

    
    
endmodule