module crc8_generator(
    input clk_in,
    input rst_in,
    input en_in,
    input start_in,
    input [64:0] data_in,
    output [7:0] crc8_out
);

    assign crc8_out = 8'hff;

endmodule
