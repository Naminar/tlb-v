
module PMU
(   input clk,
    input dtlb_hit,
    input dtlb_miss,
    // input dtlb_prefetch,
    input dtlb_insert,
    input itlb_hit,
    input itlb_miss,
    // input itlb_prefetch,
    input itlb_insert,
    input stlb_hit,
    input stlb_miss,
    input stlb_prefetch,
    input stlb_insert
);

reg [5:0] prev_state_reg = 0;

reg unsigned [63:0] dTLB_hit      = 0;
reg unsigned [63:0] dTLB_miss     = 0;
// reg unsigned [63:0] dTLB_prefetch = 0;
reg unsigned [63:0] dTLB_insert   = 0;

reg unsigned [63:0] iTLB_hit      = 0;
reg unsigned [63:0] iTLB_miss     = 0;
// reg unsigned [63:0] iTLB_prefetch = 0;
reg unsigned [63:0] iTLB_insert   = 0;

reg unsigned [63:0] STLB_hit      = 0;
reg unsigned [63:0] STLB_miss     = 0;
reg unsigned [63:0] STLB_prefetch = 0;
reg unsigned [63:0] STLB_insert   = 0;

`define GEN_STAT(trigger_wire, stat_reg)    \
if (trigger_wire == 1'b1) begin             \
    stat_reg <= stat_reg + 1'b1;            \
end                                         \


always @(posedge clk) begin

    `GEN_STAT(dtlb_hit,     dTLB_hit)
    `GEN_STAT(dtlb_miss,    dTLB_miss)
    `GEN_STAT(dtlb_insert,  dTLB_insert)

    `GEN_STAT(itlb_hit,     iTLB_hit)
    `GEN_STAT(itlb_miss,    iTLB_miss)
    `GEN_STAT(itlb_insert,  iTLB_insert)

    `GEN_STAT(stlb_hit,     STLB_hit)
    `GEN_STAT(stlb_miss,    STLB_miss)
    `GEN_STAT(stlb_insert,  STLB_insert)

    `GEN_STAT(stlb_prefetch,  STLB_prefetch)
end

endmodule