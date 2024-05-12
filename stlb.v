`define STATE_R 2:0

`define STATE                    \
parameter state_waiting = 3'b000;\
parameter state_req     = 3'b001;\
parameter state_miss    = 3'b010;\
parameter state_insert  = 3'b100;\
parameter state_shutdown= 3'b101;
// parameter state_write   = 3'b011;\

// plru_reg_n[set] <= new_plru(plru_reg_n[set], 3'111, 3'111);

`define WAY_CHECK(way, mru_value, plru_reg_n, mask, value)\
if(stlb_ways[way].w.valid[set] && stlb_ways[way].w.tag[set] == tag && stlb_ways[way].w.pcid[set] == pcid) begin\
    mru_top_reg <= mru_value;\
    plru_reg_n[set] <= new_plru(plru_reg_n[set], mask, value);\
    ta[SADDR-1:SPAGE] <= stlb_ways[way].w.pa[set];\
end else
// stlb_ways[order*4+].w.tag[set]  <= tag ;
// stlb_ways[order*4+].w.pcid[set] <= pcid;
// #TODO 
`define TREE_INVERS(plru_reg_n, order)\
plru_reg_n[set][0] <= !plru_reg_n[set][0];\
if (plru_reg_n[set][0]) begin\
    plru_reg_n[set][2] <= !plru_reg_n[set][2];\
    if (plru_reg_n[set][2]) begin\
        stlb_ways[order*4+3].w.valid[set] <= 1'b1;\
        stlb_ways[order*4+3].w.tag[set]  <= tag ;\
        stlb_ways[order*4+3].w.pcid[set] <= pcid;\
    end else begin\
        stlb_ways[order*4+2].w.valid[set] <= 1'b1;\
        stlb_ways[order*4+2].w.tag[set]  <= tag ;\
        stlb_ways[order*4+2].w.pcid[set] <= pcid;\
    end\
end else begin\
    plru_reg_n[set][1] <= !plru_reg_n[set][1];\
    if (plru_reg_n[set][1]) begin\
        stlb_ways[order*4+1].w.valid[set] <= 1'b1;\
        stlb_ways[order*4+1].w.tag[set]  <= tag ;\
        stlb_ways[order*4+1].w.pcid[set] <= pcid;\
    end else begin\
        stlb_ways[order*4].w.valid[set] <= 1'b1;\
        stlb_ways[order*4].w.tag[set]  <= tag ;\
        stlb_ways[order*4].w.pcid[set] <= pcid;\
    end\
end

module STLB 
#(
    parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=12    // way number
)
(
    input clk,
    input tlb_miss,
    input shutdown,             // clear tlb
    input insert,               // forcibly insert PTE
    input validate,             // validate or not PTE (virtual address come from va)
    input [SADDR-1:0] va,       // virtual address
    input [SADDR-1:0] pa,       // physical address
    input [SPCID-1:0] pcid,     // process-context identifier
    output reg [SADDR-1:0] ta,  // translated address
    output reg hit,
    output reg miss
);

function [3:0] new_plru(input [3:0] old_plru, input [3:0] mask, input [3:0] value);
    begin 
        new_plru = (old_plru & !mask) | (mask & value);
    end
endfunction 

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)];

`STATE 

reg [`STATE_R] state = state_waiting;

reg [1:0] mru_top_reg;
reg [2:0] plru_reg_1 [NSET-1:0];
reg [2:0] plru_reg_2 [NSET-1:0];
reg [2:0] plru_reg_3 [NSET-1:0]; 

reg [SADDR-1:0] prev_addr = 0;
reg [SPCID-1:0] prev_pcid = 0;

integer a;
initial begin
    mru_top_reg <= 0;
    for (a = 0; a < NSET; a = a + 1)
        plru_reg_1[a] = 0;
        plru_reg_2[a] = 0;
        plru_reg_3[a] = 0;
end

/********************************************************************
                             STATE MACHINE
********************************************************************/
wire [NWAY-1:0] way_hit;
wire [SADDR-SPAGE-1:0] way_ta [NWAY-1:0];
reg [NWAY-1:0] write = 0;

genvar ind;
generate
    for (ind = 0; ind < NWAY; ind = ind + 1) begin: stlb_ways
        STLB_WAY  w(shutdown, validate, va[SPAGE-1:0], pcid);
    end
endgenerate
 

always @(posedge clk) begin
    
    // if (state != state_shutdown && ( prev_addr != va || pcid != prev_pcid)) begin
    if (state != state_shutdown && tlb_miss) begin
       state <= state_req;
    //    prev_addr <= va;
    //    prev_pcid <= pcid;
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
            `WAY_CHECK(0, 2'b00, plru_reg_1, 3'b011, 3'b000)
            `WAY_CHECK(1, 2'b00, plru_reg_1, 3'b011, 3'b010)
            `WAY_CHECK(2, 2'b00, plru_reg_1, 3'b101, 3'b001)
            `WAY_CHECK(3, 2'b00, plru_reg_1, 3'b101, 3'b101)

            `WAY_CHECK(4, 2'b01, plru_reg_2, 3'b011, 3'b000)
            `WAY_CHECK(5, 2'b01, plru_reg_2, 3'b011, 3'b010)
            `WAY_CHECK(6, 2'b01, plru_reg_2, 3'b101, 3'b001)
            `WAY_CHECK(7, 2'b01, plru_reg_2, 3'b101, 3'b101)
            
            `WAY_CHECK(8,  2'b10, plru_reg_3, 3'b011, 3'b000)
            `WAY_CHECK(9,  2'b10, plru_reg_3, 3'b011, 3'b010)
            `WAY_CHECK(10, 2'b10, plru_reg_3, 3'b101, 3'b001)
            `WAY_CHECK(11, 2'b10, plru_reg_3, 3'b101, 3'b101)
            begin
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
            case (mru_top_reg)
                // SHIFTING:
                2'b00: begin
                    `TREE_INVERS(plru_reg_2, 1)
                end 
                2'b01: begin
                    `TREE_INVERS(plru_reg_3, 2)
                end
                2'b10: begin
                    `TREE_INVERS(plru_reg_1, 0)
                end
                default:; 
            endcase
            if(mru_top_reg == 2'b10)
                mru_top_reg <= 2'b00;
            else
                mru_top_reg <= mru_top_reg + 1'b1;
            state <= state_waiting; 
        end

        state_shutdown: begin
            // inside-way process
            state <= state_waiting;
        end
        default: ;
    endcase
end
endmodule