module set 
#(  parameter addr=64, //bit 
    parameter page=12, //bit
    parameter pcid_b=12, //bit
    parameter way=8, // number
    parameter set_num=8
)  
(   input clk,
    input enable, 
    input [addr-1-page-$clog2(set_num):0] tag, 
    input [pcid_b-1:0] pcid,
    input X_X, // 0 translate, 1 insert
    input [addr-page-1:0] pull_phys_add, // pulling address dut to miss
    output reg hit,
    output reg [addr-page-1:0] push_phys_addr, // translated result of va
    output reg clr
);
    reg [addr-page+pcid_b-$clog2(set_num)-1:0] va [way-1:0]; //[$clog2(way)-1:0];
    reg [addr-page-1:0] pa [way-1:0]; //[$clog2(way)-1:0];
    reg [way-2:0] plru;
    reg mode; 
    // concatinate and tag note inside cache
    wire [addr-1:0] comp_addr = {tag, pcid}; 
    // hit <= 1'b0; 
    initial begin: set_init
        integer  i;
        hit = 0;
        clr = 0;
        mode = 0;
        for (i = 0; i < way; i = i + 1) begin
            va[i] = 0;
        end
        for (i = 0; i < way-1; i = i + 1) begin
            plru[i] = 0;
        end
    end 
    
    integer ind;
    integer bit = 0;
    always @(negedge clk) begin
        // hit
        // if hit -> rebuild plru tree
        // clr = 0;
        clr <= mode;
        if (!enable) begin
            clr <= 0;
            mode <= 0;
            hit <= 0;
        end
        
        if (enable && !mode) begin
            hit <= 1'b1;
            clr <= 1;
            if (va[0] == comp_addr) begin
                plru[0] = 1'b0;
                plru[1] = 1'b0;
                plru[3] = 1'b0;
                push_phys_addr <= pa[0];
                // enable <= 0;
            end else if (va[1] == comp_addr) begin
                plru[0] = 1'b0;
                plru[1] = 1'b0;
                plru[3] = 1'b1;
                push_phys_addr <= pa[1];
                // enable <= 0;
            end else if (va[2] == comp_addr) begin
                plru[0] = 1'b0;
                plru[1] = 1'b1;
                plru[4] = 1'b0;
                push_phys_addr <= pa[2];
                // enable <= 0;
            end else if (va[3] == comp_addr) begin
                plru[0] = 1'b0;
                plru[1] = 1'b1;
                plru[4] = 1'b1;
                push_phys_addr <= pa[3];
                // enable <= 0;
            end else if (va[4] == comp_addr) begin
                plru[0] = 1'b1;
                plru[2] = 1'b0;
                plru[5] = 1'b0;
                push_phys_addr <= pa[4];
                // enable <= 0;
            end else if (va[5] == comp_addr) begin
                plru[0] = 1'b1;
                plru[2] = 1'b0;
                plru[5] = 1'b1;
                push_phys_addr <= pa[5];
                // enable <= 0;
            end else if (va[6] == comp_addr) begin
                plru[0] = 1'b1;
                plru[2] = 1'b1;
                plru[6] = 1'b0;
                push_phys_addr <= pa[6];
                // enable <= 0;
            end else if (va[7] == comp_addr) begin
                plru[0] = 1'b1;
                plru[2] = 1'b1;
                plru[6] = 1'b1; 
                push_phys_addr <= pa[7];
                // enable <= 0;
            end else begin
                hit <= 1'b0;
                mode <= 1'b1;
                clr <= 0;
            end
        end 
        // miss
        if (enable && mode) begin 
            // miss
            // clr = 1;
            clr <= mode;
            hit <= 1'b0;
            mode <= 0;
            // invers plru tree and find cell to put data
            if (plru[0]) begin
                plru[0] = !plru[0];
                if (plru[1]) begin
                    plru[1] = !plru[1];
                    plru[3] = !plru[3];
                    bit=3;
                end else begin
                    plru[1] = !plru[1];
                    plru[4] = !plru[4];
                    bit=4;
                end
            end else begin
                plru[0] = !plru[0];
                if (plru[2]) begin
                    plru[2] = !plru[2];
                    plru[5] = !plru[5];
                    bit=5;
                end else begin
                    plru[2] = !plru[2];
                    plru[6] = !plru[6];
                    bit=6;
                end
            end

            // put data to the cell
            case (bit)
                3: begin 
                    va[bit-3+plru[bit]] <= comp_addr; 
                    pa[bit-3+plru[bit]] <= pull_phys_add;
                end
                4: begin
                    va[bit-2+plru[bit]] <= comp_addr; 
                    pa[bit-2+plru[bit]] <= pull_phys_add;
                end
                5: begin 
                    va[bit-1+plru[bit]] <= comp_addr; 
                    pa[bit-1+plru[bit]] <= pull_phys_add;
                end
                6: begin 
                    va[bit+plru[bit]] <= comp_addr;
                    pa[bit+plru[bit]] <= pull_phys_add;
                end
                default: begin 
                    va[0] <= comp_addr;
                    pa[0] <= pull_phys_add; 
                end
            endcase
        end
    end

    // always @(negedge clk)
    //     hit = 1'b0;

endmodule

module cache 
#(
    parameter addr=64, //bit 
    parameter page=12, //bit
    parameter set_num=8, //number
    parameter pcid=12, //bit
    parameter way=8 // number
)
(
    input clk,
    input  [addr-1:0] va,
    input  [addr-1:0] pa,
    input  [pcid-1:0] in_pcid,
    output reg [addr-1:0] o_addr,
    output [set_num-1:0]hit
);

reg [addr-1:0]  prev_addr;

wire [page-1:0] local_addr = va[page-1:0];
wire [$clog2(set_num)-1:0] set = va[page+$clog2(set_num)-1:page];
wire [addr-1-page-$clog2(set_num):0] tag = va[addr-1:page+$clog2(set_num)];
reg [set_num-1:0] enable;
// wire [set_num-1:0] hit;
wire [set_num-1:0] clr_set;
reg mode;
wire [addr-page-1:0] transl_pa [set_num-1:0];
wire [addr-page-1:0] insrt_pa = pa[addr-1:page]; 
// genvar ind;
// // generate: name
//     for (ind = 0; ind < set_num; ind = ind + 1) begin: tlb_set
//         set tlb_set (clk, enable[ind], tag, set, in_pcid, hit[ind]);
//     end
// // endgenerate

set _set_0(clk, enable[0], tag, in_pcid, mode, insrt_pa, hit[0], transl_pa[0], clr_set[0]);
set _set_1(clk, enable[1], tag, in_pcid, mode, insrt_pa, hit[1], transl_pa[1], clr_set[1]);
set _set_2(clk, enable[2], tag, in_pcid, mode, insrt_pa, hit[2], transl_pa[2], clr_set[2]);
set _set_3(clk, enable[3], tag, in_pcid, mode, insrt_pa, hit[3], transl_pa[3], clr_set[3]);

set _set_4(clk, enable[4], tag, in_pcid, mode, insrt_pa, hit[4], transl_pa[4], clr_set[4]);
set _set_5(clk, enable[5], tag, in_pcid, mode, insrt_pa, hit[5], transl_pa[5], clr_set[5]);
set _set_6(clk, enable[6], tag, in_pcid, mode, insrt_pa, hit[6], transl_pa[6], clr_set[6]);
set _set_7(clk, enable[7], tag, in_pcid, mode, insrt_pa, hit[7], transl_pa[7], clr_set[7]);    

initial begin
    enable = 0;
    prev_addr = 0;
    mode = 0;
end

always @(posedge clk) begin
    // enable = 0;

    if (clr_set != 0) begin
        case (set)
            0: o_addr <= {transl_pa[0], local_addr};
            1: o_addr <= {transl_pa[1], local_addr};
            2: o_addr <= {transl_pa[2], local_addr};
            3: o_addr <= {transl_pa[3], local_addr}; 
            4: o_addr <= {transl_pa[4], local_addr}; 
            5: o_addr <= {transl_pa[5], local_addr}; 
            6: o_addr <= {transl_pa[6], local_addr}; 
            default:  o_addr <= {transl_pa[7], local_addr}; 
        endcase
        enable = 0;
    end

    if (prev_addr != va) begin
        // mode = 0; // try to translate
        case (set)
            0: begin enable = 0; enable[0] = 1'b1; end
            1: begin enable = 0; enable[1] = 1'b1; end 
            2: begin enable = 0; enable[2] = 1'b1; end
            3: begin enable = 0; enable[3] = 1'b1; end
            4: begin enable = 0; enable[4] = 1'b1; end
            5: begin enable = 0; enable[5] = 1'b1; end
            6: begin enable = 0; enable[6] = 1'b1; end
            default: begin enable = 0; enable[7] = 1'b1; end
        endcase
        prev_addr <= va;
    end
    // end else begin 
    //     enable = 0;
    // end
end
endmodule