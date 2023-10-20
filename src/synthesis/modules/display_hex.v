module display_hex (
    input [15:0] in,
    output [27:0] out
);

    genvar i;
    generate
    for (i = 0; i < 4; i = i + 1) begin : name
        wire [3:0] digit = in[4 * i + 3 : 4 * i];
        hex hex_inst (
            digit,
            out[7 * i + 6 : 7 * i]
        );
    end
    endgenerate

    //assign out[20:14] = (out[20:14] != ~7'h3F) ? out[20:14] : ~7'h00;
    //assign out[27:21] = (out[27:21] != ~7'h3F) ? out[27:21] : ~7'h00;
    
endmodule