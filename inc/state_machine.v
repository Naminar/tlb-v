`define STATE_MACHINE(bank)                                                                     \
always @(posedge clk) begin                                                                     \
    if (request_``bank) begin                                                                   \
            hit_``bank <= 1'b1;                                                                 \
            state_``bank <= state_waiting;                                                      \
            `WAY_CHECK(bank, 0, 2'b00, plru_reg_1, 3'b011, 3'b000)                              \
            `WAY_CHECK(bank, 1, 2'b00, plru_reg_1, 3'b011, 3'b010)                              \
            `WAY_CHECK(bank, 2, 2'b00, plru_reg_1, 3'b101, 3'b001)                              \
            `WAY_CHECK(bank, 3, 2'b00, plru_reg_1, 3'b101, 3'b101)                              \
                                                                                                \
            `WAY_CHECK(bank, 4, 2'b01, plru_reg_2, 3'b011, 3'b000)                              \
            `WAY_CHECK(bank, 5, 2'b01, plru_reg_2, 3'b011, 3'b010)                              \
            `WAY_CHECK(bank, 6, 2'b01, plru_reg_2, 3'b101, 3'b001)                              \
            `WAY_CHECK(bank, 7, 2'b01, plru_reg_2, 3'b101, 3'b101)                              \
                                                                                                \
            `WAY_CHECK(bank, 8,  2'b10, plru_reg_3, 3'b011, 3'b000)                             \
            `WAY_CHECK(bank, 9,  2'b10, plru_reg_3, 3'b011, 3'b010)                             \
            `WAY_CHECK(bank, 10, 2'b10, plru_reg_3, 3'b101, 3'b001)                             \
            `WAY_CHECK(bank, 11, 2'b10, plru_reg_3, 3'b101, 3'b101)                             \
            begin                                                                               \
                miss_``bank <= 1'b1;                                                            \
                hit_``bank <= 1'b0;                                                             \
                state_``bank <= state_miss;                                                     \
            end                                                                                 \
        end                                                                                     \
    case (state_``bank)                                                                         \
        state_miss: begin                                                                       \
            miss_``bank <= 1'b0;                                                                \
            ta_``bank[SADDR-1:0] <= {pa_``bank[SADDR-1:SPAGE], local_addr_``bank};              \
            state_``bank <= state_insert;                                                       \
        end                                                                                     \
        state_insert: begin                                                                     \
            case (mru_top_reg[set_``bank])                                                      \
                2'b00: begin                                                                    \
                    `TREE_INVERS(bank, plru_reg_2, 1)                                           \
                end                                                                             \
                2'b01: begin                                                                    \
                    `TREE_INVERS(bank, plru_reg_3, 2)                                           \
                end                                                                             \
                2'b10: begin                                                                    \
                    `TREE_INVERS(bank, plru_reg_1, 0)                                           \
                end                                                                             \
                default:;                                                                       \
            endcase                                                                             \
            if(mru_top_reg[set_``bank] == 2'b10)                                                \
                mru_top_reg[set_``bank] <= 2'b00;                                               \
            else                                                                                \
                mru_top_reg[set_``bank] <= mru_top_reg[set_``bank] + 1'b1;                      \
            state_``bank <= state_waiting;                                                      \
        end                                                                                     \
        state_shutdown: begin                                                                   \
            state_``bank <= state_waiting;                                                      \
        end                                                                                     \
        default: ;                                                                              \
    endcase                                                                                     \
end