module set 
#(  parameter addr=64, //bit 
    parameter page=12, //bit
    // parameter sett=8, //number
    parameter pcid=12, //bit
    parameter way=8 // number
)  
( //   input clk, 
//     output reg [addr-page+pcid-1:0] block
);
    reg [addr-page+pcid-1:0] blocks [$clog2(way)-1:0];
    reg [$clog2(way)-1:0] plru;

    initial begin: my_init
        integer  i;
        for (i = 0; i < way; i = i + 1) begin
            blocks[i] = 0;
        end
    end 
    
    // always @(posedge clk) begin
    //     block <= cell[0];
    // end
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
    input  [addr-1:0] in_addr,
    input  [pcid-1:0] in_pcid,
    output [addr-1:0] o_addr
);
    reg [addr-1:0] prev_addr;
    reg [page-1:0] phys_addr;
    reg [$clog2(set_num):0] index;
    reg [addr-page+pcid-1:0] sets [$clog2(set_num)-1:0] [$clog2(way)-1:0];
    reg [$clog2(way)-1:0]    plru [$clog2(set_num)-1:0] [$clog2(way)-1:0];


    integer i_set;
    integer i_block;
    initial begin: initialize
        prev_addr = 0;
        for (i_set = 0; i_set < set_num; i_set = i_set + 1) begin
            for (i_block = 0; i_block < way; i_block = i_block +1) begin
                sets[i_set][i_block] = 0; // null addresses inside each cache block
                plru[i_set][i_block] = 0;
            end
        end
    end  

    reg set_line, inside_phys_addr, tag, comp_addr;

    always @(posedge clk) begin
        if (in_addr != prev_addr) begin
            prev_addr = in_addr;
            inside_phys_addr = in_addr[page-1:0];
            set_line = in_addr[page+$clog2(set_num)-1:page];
            tag = in_addr[addr-1:page+$clog2(set_num)];
            comp_addr = {tag, set_line, in_pcid};
            // sets[set_line][0] = 64'b1;
            for (i_block = 0; i_block < way; i_block = i_block +1) begin
                if (sets[set_line][i_block] == comp_addr) begin
                // hit in block with i index
                
                end else begin 
                // miss in set with set_line index

                end
            end
        end
    end

endmodule