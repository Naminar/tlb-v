module way 
#(  parameter SADDR=64, // size of address
    parameter SPAGE=12, // size of page
    parameter NSET=8,   // set number
    parameter SPCID=12, // size of pcid
    parameter NWAY=8    // way number
)  ();

    reg [SADDR-$clog2(NWAY)-1:0]    tag  [NSET-1:0];
    reg [SPCID-1:0]                 pcid [NSET-1:0];
    reg [SADDR-SPAGE-1:0]           pa   [NSET-1:0];

    integer i;
    initial begin
        for (i = 0; i < NSET; i = i + 1) begin
            pa[i]   = 0;        
            pcid[i] = 0;
            tag[i]  = 0;
        end        
    end
endmodule