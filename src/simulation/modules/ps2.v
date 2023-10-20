module ps2 (
    input key_clock,
    input key_data,
    input rst_n,
    input clk,
    output [15:0] out
);
    reg [63:0] code_reg, code_next;
    reg [1:0] state_reg, state_next;
    reg flag_reg, flag_next; // marks the end of a code 
    integer byte_index_reg, byte_index_next;

    localparam data = 2'd1;
    localparam parity = 2'd2;
    localparam stop = 2'd3;

    assign out = code_reg[15:0];

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            code_reg <= 64'h0000000000000000;
            state_reg <= stop;
            flag_reg <= 1'b0;
            byte_index_reg <= 0;
        end
        else begin
            code_reg <= code_next;
            state_reg <= state_next;
            flag_reg <= flag_next;
            byte_index_reg <= byte_index_next;
        end
    end

    always @(negedge key_clock) begin
        code_next = code_reg;
        state_next = state_reg;
        flag_next = flag_reg;
        byte_index_next = byte_index_reg;
        case (state_reg)
            data: begin
                code_next[byte_index_reg] = key_data;

                byte_index_next = byte_index_reg + 1;
                if (byte_index_reg == 7) begin
                    state_next = parity;
                    byte_index_next = 0;
                end
            end
            parity: begin
                state_next = stop;
                if (^code_reg[7:0] == key_data) code_next[7:0] = 8'hFF;
            end
            stop: begin
                if (code_reg[7:0] == 8'hE0 || code_reg[7:0] == 8'hF0 || code_reg[15:0] == 16'hE012 || code_reg[23:0] == 24'hE0F07C ||
                    code_reg[7:0] == 8'hE1 || code_reg[15:0] == 16'hE114 || code_reg[23:0] == 24'hE11477 || code_reg[23:0] == 24'hE1F014) begin
                    code_next = code_reg << 8;
                    flag_next = 1'b0;
                end
                else begin
                    flag_next = 1'b1;
                end
                if (!key_data) begin
                    state_next = data;
                    if (flag_reg) code_next = 64'h0000000000000000;
                end 
            end
        endcase
    end
    
endmodule