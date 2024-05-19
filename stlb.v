`include "inc/range.v"
`include "inc/state.v"

`define WAY_CHECK(way, mru_value, plru_reg_n, mask, value)                                  \
if(entries[set][way]`VALIDE_BIT                                                             \
    && entries[set][way]`TAG_RANGE == tag                                                   \
    && entries[set][way]`PCID_RANGE == pcid)                                                \
    begin                                                                                   \
        mru_top_reg <= mru_value;                                                           \
        plru_reg_n[set] <= new_plru(plru_reg_n[set], mask, value);                          \
        ta[SADDR-1:SPAGE] <= entries[set][way][SADDR-SPAGE-1:0];                            \
end else

`define TREE_INVERS(plru_reg_n, order)                                                      \
plru_reg_n[set][0] <= !plru_reg_n[set][0];                                                  \
if (!plru_reg_n[set][0]) begin                                                              \
    plru_reg_n[set][2] <= !plru_reg_n[set][2];                                              \
    if (!plru_reg_n[set][2]) begin                                                          \
        entries[set][order*4+3]`VALIDE_BIT <= 1'b1;                                         \
        entries[set][order*4+3]`TAG_RANGE  <= tag ;                                         \
        entries[set][order*4+3]`PCID_RANGE <= pcid;                                         \
    end else begin                                                                          \
        entries[set][order*4+2]`VALIDE_BIT <= 1'b1;                                         \
        entries[set][order*4+2]`TAG_RANGE  <= tag ;                                         \
        entries[set][order*4+2]`PCID_RANGE <= pcid;                                         \
    end                                                                                     \
end else begin                                                                              \
    plru_reg_n[set][1] <= !plru_reg_n[set][1];                                              \
    if (!plru_reg_n[set][1]) begin                                                          \
        entries[set][order*4+1]`VALIDE_BIT <= 1'b1;                                         \
        entries[set][order*4+1]`TAG_RANGE  <= tag ;                                         \
        entries[set][order*4+1]`PCID_RANGE <= pcid;                                         \
    end else begin                                                                          \
        entries[set][order*4]`VALIDE_BIT <= 1'b1;                                           \
        entries[set][order*4]`TAG_RANGE  <= tag ;                                           \
        entries[set][order*4]`PCID_RANGE <= pcid;                                           \
    end                                                                                     \
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

function [2:0] new_plru(input [2:0] old_plru, input [2:0] mask, input [2:0] value);
    begin 
        new_plru = (old_plru & ~mask) | (mask & value);
    end
endfunction 

`STATE

wire [SPAGE-1:0]                    local_addr      = va[SPAGE-1:0];
wire [$clog2(NSET)-1:0]             set             = va[SPAGE+$clog2(NSET)-1:SPAGE];
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag             = va[SADDR-1:SPAGE+$clog2(NSET)]; 

reg [`STATE_R] state;
reg [1:0] mru_top_reg;
reg [2:0] plru_reg_1 [NSET-1:0];
reg [2:0] plru_reg_2 [NSET-1:0];
reg [2:0] plru_reg_3 [NSET-1:0]; 
reg [SADDR-$clog2(NSET)-SPAGE+SPCID+SADDR-SPAGE:0] entries [NSET-1:0][NWAY-1:0];

initial begin: init_plru_and_entries
    integer  w_ind, s_ind, a;
    mru_top_reg     = 0;
    state[`STATE_R] = state_waiting;
    
    for (a = 0; a < NSET; a = a + 1) begin
        plru_reg_1[a] = 0;
        plru_reg_2[a] = 0;
        plru_reg_3[a] = 0;
    end
    
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
            if (state == state_shutdown) begin: shutdown_stlb
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
    if (state != state_shutdown && tlb_miss) begin
       state <= state_req;
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
            miss <= 1'b0;    
            ta[SADDR-1:0] <= {pa[SADDR-1:SPAGE], local_addr};
            state <= state_insert;
        // end state_miss
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
        // end state_insert
        end

        state_shutdown: begin
            // another always block: line 108
            state <= state_waiting;
        // end state_shutdown
        end
        default: ;
    endcase
end
endmodule