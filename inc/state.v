`ifndef STATE_V
`define STATE_V

//state ranege
`define STATE_R 5:0
`define STATE                       \
parameter state_waiting = 6'b000000;\
parameter state_req     = 6'b000001;\
parameter state_miss    = 6'b000010;\
parameter state_insert  = 6'b000100;\
parameter state_shutdown= 6'b001000;\
parameter state_push    = 6'b010000;\
parameter state_validate= 6'b100000;
// parameter state_write   = 3'b011;\

`define req_bit         [0]
`define miss_bit        [1]
`define insert_bit      [2]
`define shutdown_bit    [3]
`define push_bit        [4]
`define validate_bit    [5]

`endif // STATE_V