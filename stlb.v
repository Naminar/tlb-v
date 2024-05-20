`include "inc/range.v"
`include "inc/state.v"
`include "inc/state_machine.v"

`define WAY_CHECK(bank, way, mru_value, plru_reg_n, mask, value)                                            \
        if(entries[set_``bank][way]`VALIDE_BIT                                                              \
            && entries[set_``bank][way]`TAG_RANGE == tag_``bank                                             \
            && entries[set_``bank][way]`PCID_RANGE == pcid_``bank)                                          \
            begin                                                                                           \
                mru_top_reg[set_``bank] <= mru_value;                                                       \
                plru_reg_n[set_``bank] <= new_plru(plru_reg_n[set_``bank], mask, value);                    \
                ta_``bank[SADDR-1:0] <= {entries[set_``bank][way][SADDR-SPAGE-1:0], local_addr_``bank};     \
        end else

`define TREE_INVERS(bank, plru_reg_n, order)                                                                \
                    plru_reg_n[set_``bank][0] <= !plru_reg_n[set_``bank][0];                                \
                    if (!plru_reg_n[set_``bank][0]) begin                                                   \
                        plru_reg_n[set_``bank][2] <= !plru_reg_n[set_``bank][2];                            \
                        if (!plru_reg_n[set_``bank][2]) begin                                               \
                            entries[set_``bank][order*4+3]`VALIDE_BIT <= 1'b1;                              \
                            entries[set_``bank][order*4+3]`TAG_RANGE  <= tag_``bank ;                       \
                            entries[set_``bank][order*4+3]`PCID_RANGE <= pcid_``bank;                       \
                        end else begin                                                                      \
                            entries[set_``bank][order*4+2]`VALIDE_BIT <= 1'b1;                              \
                            entries[set_``bank][order*4+2]`TAG_RANGE  <= tag_``bank ;                       \
                            entries[set_``bank][order*4+2]`PCID_RANGE <= pcid_``bank;                       \
                        end                                                                                 \
                    end else begin                                                                          \
                        plru_reg_n[set_``bank][1] <= !plru_reg_n[set_``bank][1];                            \
                        if (!plru_reg_n[set_``bank][1]) begin                                               \
                            entries[set_``bank][order*4+1]`VALIDE_BIT <= 1'b1;                              \
                            entries[set_``bank][order*4+1]`TAG_RANGE  <= tag_``bank ;                       \
                            entries[set_``bank][order*4+1]`PCID_RANGE <= pcid_``bank;                       \
                        end else begin                                                                      \
                            entries[set_``bank][order*4]`VALIDE_BIT <= 1'b1;                                \
                            entries[set_``bank][order*4]`TAG_RANGE  <= tag_``bank ;                         \
                            entries[set_``bank][order*4]`PCID_RANGE <= pcid_``bank;                         \
                        end                                                                                 \
                    end

`define PORTS_INIT(bank)               \
    input request_``bank,              \
    input [SADDR-1:0] va_``bank,       \
    input [SADDR-1:0] pa_``bank,       \
    input [SPCID-1:0] pcid_``bank,     \
    output reg [SADDR-1:0] ta_``bank,  \
    output reg hit_``bank,             \
    output reg miss_``bank,            \
    output reg [`STATE_R] state_``bank 

`define SECTION_INIT(bank)                                                                          \
wire [SPAGE-1:0]                    local_addr_``bank      = va_``bank[SPAGE-1:0];                  \
wire [$clog2(NSET)-1:0]             set_``bank             = va_``bank[SPAGE+$clog2(NSET)-1:SPAGE]; \
wire [SADDR-1-SPAGE-$clog2(NSET):0] tag_``bank             = va_``bank[SADDR-1:SPAGE+$clog2(NSET)]; 
// assign local_addr_``bank      = va_``bank[SPAGE-1:0];                  \
// assign set_``bank             = va_``bank[SPAGE+$clog2(NSET)-1:SPAGE]; \
// assign tag_``bank             = va_``bank[SADDR-1:SPAGE+$clog2(NSET)]; 

module STLB 
#(
    parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=12   // way number
)
(
    input clk,
    `PORTS_INIT(bank0),
    `PORTS_INIT(bank1),
    `PORTS_INIT(bank2),
    `PORTS_INIT(bank3)
);

function [2:0] new_plru(input [2:0] old_plru, input [2:0] mask, input [2:0] value);
    begin 
        new_plru = (old_plru & ~mask) | (mask & value);
    end
endfunction 

`STATE
`SECTION_INIT(bank0)
`SECTION_INIT(bank1)
`SECTION_INIT(bank2)
`SECTION_INIT(bank3)        

reg [1:0] mru_top_reg [NSET-1:0];
reg [2:0] plru_reg_1 [NSET-1:0];
reg [2:0] plru_reg_2 [NSET-1:0];
reg [2:0] plru_reg_3 [NSET-1:0]; 
reg [SADDR-$clog2(NSET)-SPAGE+SPCID+SADDR-SPAGE:0] entries [NSET-1:0][NWAY-1:0];

initial begin: init_plru_and_entries
    integer  w_ind, s_ind;
    state_bank0[`STATE_R] = state_waiting;
    state_bank1[`STATE_R] = state_waiting;
    state_bank2[`STATE_R] = state_waiting;
    state_bank3[`STATE_R] = state_waiting;
    
    for (s_ind = 0; s_ind < NSET; s_ind = s_ind + 1) begin
        for (w_ind = 0; w_ind < NWAY; w_ind = w_ind + 1) begin
            entries[s_ind][w_ind]`VALIDE_BIT    = 0;
            entries[s_ind][w_ind]`TAG_RANGE     = 0;
            entries[s_ind][w_ind]`PCID_RANGE    = 0;
            entries[s_ind][w_ind]`PA_RANGE      = 0; 
        end
        mru_top_reg[s_ind] = 0;
        plru_reg_1[s_ind] = 0;
        plru_reg_2[s_ind] = 0;
        plru_reg_3[s_ind] = 0;
    end
end

/********************************************************************
                             STATE MACHINE
********************************************************************/
// genvar s_ind;
// generate
//     for (s_ind = 0; s_ind < NSET; s_ind = s_ind + 1) begin: clear
//         always @(posedge clk) begin: shutdown_stlb
//             if (state == state_shutdown) begin: shutdown_stlb
//                 integer  w_ind;
//                 for (w_ind = 0; w_ind < NWAY; w_ind = w_ind + 1) begin
//                     entries[s_ind][w_ind]`VALIDE_BIT    <= 0;
//                     entries[s_ind][w_ind]`TAG_RANGE     <= 0;
//                     entries[s_ind][w_ind]`PCID_RANGE    <= 0;
//                     entries[s_ind][w_ind]`PA_RANGE      <= 0; 
//                 end
//             end
//         end
//     end
// endgenerate

`STATE_MACHINE(bank0)
`STATE_MACHINE(bank1)
`STATE_MACHINE(bank2)
`STATE_MACHINE(bank3)

endmodule