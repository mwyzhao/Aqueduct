module crc8_insert(
    input         clk_in,
    input         rst_in,
    input  [63:0] payload_in,
    input   [1:0] header_in,
    output [63:0] payload_out,
    output  [1:0] header_out
);

    reg         crc8_generator_enable = 1'b0;
    reg         crc8_generator_start  = 1'b0;
    reg  [63:0] crc8_generator_data  = 64'd0;
    wire  [7:0] crc8_generator_crc8;

    crc8_generator_0 crc8_generator_inst(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .en_in(crc8_generator_enable),
        .start_in(crc8_generator_start),
        .data_in(crc8_generator_data),
        .crc8_out(crc8_generator_crc8)
    );

    assign header_out = header_in;
    assign payload_out = payload_in;

endmodule
