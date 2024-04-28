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
    input [$clog2(set_num)-1:0] this_set,
    input [pcid_b-1:0]pcid,
    output reg hit
//     output reg [addr-page+pcid-1:0] block
);
    reg [addr-page+pcid_b-1:0] va [way-1:0]; //[$clog2(way)-1:0];
    reg [addr-page+pcid_b-1:0] pa [way-1:0]; //[$clog2(way)-1:0];
    reg [way-2:0] plru;

    wire [addr-1:0] comp_addr = {tag, this_set, pcid};
    // hit <= 1'b0; 

    initial begin: my_init
        integer  i;
        hit = 0;
        for (i = 0; i < way; i = i + 1) begin
            va[i] = 0;
        end
        for (i = 0; i < way-1; i = i + 1) begin
            plru[i] = 0;
        end
    end 
    
    integer ind;
    integer bit = 0;
    always @(negedge clk) begin // TODO (posedge clk and enable)
        // hit
        // if hit -> rebuild plru tree
        if (enable) begin
        hit = 1'b1;
        if (va[0] == comp_addr) begin
            plru[0] = 1'b0;
            plru[1] = 1'b0;
            plru[3] = 1'b0;
        end else if (va[1] == comp_addr) begin
            plru[0] = 1'b0;
            plru[1] = 1'b0;
            plru[3] = 1'b1;
        end else if (va[2] == comp_addr) begin
            plru[0] = 1'b0;
            plru[1] = 1'b1;
            plru[4] = 1'b0;
        end else if (va[3] == comp_addr) begin
            plru[0] = 1'b0;
            plru[1] = 1'b1;
            plru[4] = 1'b1;
        end else if (va[4] == comp_addr) begin
            plru[0] = 1'b1;
            plru[2] = 1'b0;
            plru[5] = 1'b0;
        end else if (va[5] == comp_addr) begin
            plru[0] = 1'b1;
            plru[2] = 1'b0;
            plru[5] = 1'b1;
        end else if (va[6] == comp_addr) begin
            plru[0] = 1'b1;
            plru[2] = 1'b1;
            plru[6] = 1'b0;
        end else if (va[7] == comp_addr) begin
            plru[0] = 1'b1;
            plru[2] = 1'b1;
            plru[6] = 1'b1; 
        end else begin 
            // miss
            hit = 1'b0;
            // invers plru tree and find cell to put data
            // for (ind=0;ind<3;ind=ind+1) begin
            //     if (ind != 2) begin
            //         if(plru[bit]) begin
            //             plru[bit] = !plru[bit]; // проверить !!!!
            //             bit <= bit*2 + 2;
            //         end else begin
            //             plru[bit] = !plru[bit];
            //             bit <= bit*2 + 1;
            //         end
            //     end else
            //         plru[bit] <= !plru[bit];
            // end
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
                3: va[bit-3+plru[bit]] <= comp_addr; 
                4: va[bit-2+plru[bit]] <= comp_addr; 
                5: va[bit-1+plru[bit]] <= comp_addr; 
                6: va[bit+plru[bit]]   <= comp_addr;
                default: va[0] <= comp_addr; 
            endcase


            // va[0] <= comp_addr;

        end
        end
    end

    always @(negedge clk)
        hit = 1'b0;

    // initial begin
    //     $dumpfile("set_tb.vcd");
    //     $dumpvars(1,set);
    //     // $monitor("%t | clk = %d | out = %d", $time, clk, c[0].va[0]);
    //     #100 $finish;
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
    output [addr-1:0] o_addr,
    output [way-1:0]hit
);

reg [addr-1:0]  prev_addr;
wire [page-1:0] phys_addr;

wire [page-1:0] local_addr = in_addr[page-1:0];
wire [$clog2(set_num)-1:0] set = in_addr[page+$clog2(set_num)-1:page];
wire [addr-1-page-$clog2(set_num):0] tag = in_addr[addr-1:page+$clog2(set_num)];
reg [set_num-1:0] enable;
wire [set_num-1:0] hit;

// genvar ind;
// generate
//     for (ind = 0; ind < set_num; ind = ind + 1)
//         set _set_(clk, enable[ind], tag, set, in_pcid, hit[ind]);
// endgenerate

set _set_0(clk, enable[0], tag, set, in_pcid, hit[0]);
set _set_1(clk, enable[1], tag, set, in_pcid, hit[1]);
set _set_2(clk, enable[2], tag, set, in_pcid, hit[2]);
set _set_3(clk, enable[3], tag, set, in_pcid, hit[3]);

set _set_4(clk, enable[4], tag, set, in_pcid, hit[4]);
set _set_5(clk, enable[5], tag, set, in_pcid, hit[5]);
set _set_6(clk, enable[6], tag, set, in_pcid, hit[6]);
set _set_7(clk, enable[7], tag, set, in_pcid, hit[7]);
// set s0(clk, enable[0]);
// set s1(clk, enable[0]);
// set s2();
// set s3();
// set s4();
// set s5();
// set s6();
// set s7();    

initial begin
    enable = 0;
    prev_addr = 0;
end

always @(posedge clk) begin
    // enable = 0;
    if (prev_addr != in_addr) begin
        case (set)
            0: begin enable = 0; enable[0] = 1'b1; end
            1: begin enable = 0; enable[1] = 1'b1; end 
            2: begin enable = 0; enable[2] = 1'b1; end
            3: begin enable = 0; enable[3] = 1'b1; end
            4: begin enable = 0; enable[4] = 1'b1; end
            5: begin enable = 0; enable[5] = 1'b1; end
            6: begin enable = 0; enable[6] = 1'b1; end
            default: begin enable = 0; enable[0] = 1'b1; end
        endcase
        prev_addr <= in_addr;
    end else begin 
        enable = 0;
    end
end



endmodule
// module cache 
// #(
//     parameter addr=64, //bit 
//     parameter page=12, //bit
//     parameter set_num=8, //number
//     parameter pcid=12, //bit
//     parameter way=8 // number
// )
// (
//     input clk,
//     input  [addr-1:0] in_addr,
//     input  [pcid-1:0] in_pcid,
//     output [addr-1:0] o_addr
// );
//     reg [addr-1:0] prev_addr;
//     reg [page-1:0] phys_addr;
//     reg [$clog2(set_num):0] index;
//     reg [addr-page+pcid-1:0] sets [$clog2(set_num)-1:0] [$clog2(way)-1:0];
//     reg [$clog2(way)-1:0]    plru [$clog2(set_num)-1:0] [$clog2(way)-1:0];


//     integer i_set;
//     integer i_block;
//     initial begin: initialize
//         prev_addr = 0;
//         for (i_set = 0; i_set < set_num; i_set = i_set + 1) begin
//             for (i_block = 0; i_block < way; i_block = i_block +1) begin
//                 sets[i_set][i_block] = 0; // null addresses inside each cache block
//                 plru[i_set][i_block] = 0;
//             end
//         end
//     end  

//     reg set_line, inside_phys_addr, tag, comp_addr;

//     always @(posedge clk) begin
//         if (in_addr != prev_addr) begin
//             prev_addr = in_addr;
//             inside_phys_addr = in_addr[page-1:0];
//             set_line = in_addr[page+$clog2(set_num)-1:page];
//             tag = in_addr[addr-1:page+$clog2(set_num)];
//             comp_addr = {tag, set_line, in_pcid};
//             // sets[set_line][0] = 64'b1;
//             for (i_block = 0; i_block < way; i_block = i_block +1) begin
//                 if (sets[set_line][i_block] == comp_addr) begin
//                 // hit in block with i index
//                 i_block = way;

//                 end else begin 
//                 // miss in set with set_line index

//                 end
//             end
//         end
//     end

// endmodule
