module payload_manager(
    input  [63:0] payload_in,
    input   [1:0] header_in,
    output [63:0] payload_out,
    output  [1:0] header_out,
    output        valid_out
);

    localparam H_CTRL = 2'b10;
    localparam T_IDLE = 8'h00;

    assign valid_out = !(header_in == H_CTRL && payload_in[63:56] == T_IDLE);
    assign header_out = header_in;
    assign payload_out = payload_in;

endmodule
