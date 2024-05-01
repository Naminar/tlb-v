
module pmu
(   input clk,
    input tlb_hit,
    input tlb_miss,
    input tlb_prefetch,
    output [63:0] out1,
    output [63:0] out2,
    output [63:0] out3
);

reg [2:0] prev_state_reg = 0;

reg unsigned [63:0] dTLB_hit      = 0;
reg unsigned [63:0] dTLB_miss     = 0;
reg unsigned [63:0] dTLB_prefetch = 0;

assign out1 = dTLB_hit;
assign out2 = dTLB_miss;
assign out3 = dTLB_prefetch;

always @(posedge clk) begin

    if (prev_state_reg[0] == 1'b0 && tlb_hit == 1'b1)
        dTLB_hit <= dTLB_hit + 1'b1;     
    prev_state_reg[0] <= tlb_hit;

    if (prev_state_reg[1] == 1'b0 && tlb_miss == 1'b1)
        dTLB_miss <= dTLB_miss + 1'b1;     
    prev_state_reg[1] <= tlb_miss;

    if (prev_state_reg[2] == 1'b0 && tlb_prefetch == 1'b1)
        dTLB_prefetch <= dTLB_prefetch + 1'b1;   
    prev_state_reg[2] <= tlb_prefetch;
end
    
endmodule