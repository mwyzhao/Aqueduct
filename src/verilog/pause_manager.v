module pause_manager(
    input      clk_in,
    input      rst_in,
    input      pause_0_in,
    input      unpause_0_in,
    input      pause_unpause_0_in,
    output     inject_pause_out
);

    reg  pause_0_reg;
    reg  unpause_0_reg;
    
    wire set_pause_0;
    wire reset_pause_0;
    
    reg  pause_unpause_0_gen;
    reg  pause_unpause_0_reg;

    // generate pulses for each dual input
    assign set_pause_0   = !pause_0_reg && pause_0_in;
    assign reset_pause_0 = !unpause_0_reg && unpause_0_in;

    always @(posedge clk_in) begin
        if(rst_in) begin
            pause_unpause_0_gen <= 1'b0;
        end
        else begin
            // register for edge detection for each dual input
            pause_0_reg   <= pause_0_in;
            unpause_0_reg <= unpause_0_in;
            // register pause unpause for each input
            case({set_pause_0,reset_pause_0})
                2'b00: pause_unpause_0_gen <= pause_unpause_0_gen;
                2'b01: pause_unpause_0_gen <= 1'b0;
                2'b10: pause_unpause_0_gen <= 1'b1;
                2'b11: pause_unpause_0_gen <= pause_unpause_0_gen;
            endcase
            pause_unpause_0_reg <= pause_unpause_0_in;
        end
    end

    // assign output
    assign inject_pause_out = pause_unpause_0_gen ||
                              pause_unpause_0_reg;

endmodule
