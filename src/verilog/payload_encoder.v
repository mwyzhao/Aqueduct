module payload_encoder(
    input             clk_in,
    input             rst_in,
    input      [63:0] s_axis_tdata,
    input       [7:0] s_axis_tkeep,
    input       [7:0] s_axis_tuser,
    input       [7:0] s_axis_tdest,
    input             s_axis_tlast,
    input             s_axis_tvalid,
    output            s_axis_tready,
    input             inject_pause_in,
    input             pause_in,
    output reg [63:0] payload_out,
    output reg  [1:0] header_out
);

    // Signals and parameters

    // Encoding parameters
    localparam T_S1    = 8'h1e;
    localparam T_S2    = 8'h2d;
    localparam T_S3    = 8'h33;
    localparam T_S4    = 8'h4b;
    localparam T_S5    = 8'h55;
    localparam T_T0    = 8'h66;
    localparam T_T1    = 8'h78;
    localparam T_T2    = 8'h87;
    localparam T_T3    = 8'h99;
    localparam T_T4    = 8'haa;
    localparam T_T5    = 8'hb4;
    localparam T_T6    = 8'hcc;
    localparam T_T7    = 8'hd2;

    localparam T_IDLE  = 8'h00;
    localparam T_ERROR = 8'he1;
    localparam T_PAUSE = 8'hff;

    localparam H_DATA  = 2'b01;
    localparam H_CTRL  = 2'b10;

    // Special encoding transfers
    wire [63:0] PAUSE   = {T_PAUSE,s_axis_tuser,{8{1'b0}},{32{1'b1}},{8{1'b0}}};
    wire [63:0] UNPAUSE = {T_PAUSE,s_axis_tuser,{8{1'b0}},{32{1'b0}},{8{1'b0}}};
    wire [63:0] IDLE    = {T_IDLE,{56{1'b0}}};

    // Handshake overflow buffer control
    wire       load_buf;
    wire       load_from_buf;

    // User interface buffers
    reg [63:0] s_axis_tdata_reg;
    reg  [7:0] s_axis_tkeep_reg;
    reg  [7:0] s_axis_tuser_reg;
    reg  [7:0] s_axis_tdest_reg;
    reg        s_axis_tlast_reg;
    reg        s_axis_tvalid_reg;
    reg        s_axis_tready_reg;

    // Handshake overflow buffers
    reg [63:0] s_axis_tdata_buf;
    reg  [7:0] s_axis_tkeep_buf;
    reg  [7:0] s_axis_tuser_buf;
    reg  [7:0] s_axis_tdest_buf;
    reg        s_axis_tlast_buf;
    reg        s_axis_tvalid_buf;
    reg        s_axis_tready_int;

    // Control buffers
    reg        inject_pause_reg;
    reg        pause_reg;

    // Control signals
    wire       inject_pause;
    wire       inject_unpause;

    // Internal buffers
    reg [23:0] tdata_temp;
    reg  [2:0] tkeep_temp;

    // State parameters
    localparam START       = 3'b001;
    localparam SEND_MIDDLE = 3'b010;
    localparam SEND_LAST   = 3'b100;
    
    reg  [2:0] state;
    reg  [2:0] next_state;
    
    // Combinational logic

    // Helper functions
    function [63:0] start_payload;
        input  [7:0] tkeep;
        input  [7:0] tuser;
        input  [7:0] tdest;
        input [63:0] tdata;
            case(tkeep)
                8'h80: start_payload = {T_S1,tuser,tdest,tdata[63:56],{32{1'b0}}};
                8'hc0: start_payload = {T_S2,tuser,tdest,tdata[63:48],{24{1'b0}}};
                8'he0: start_payload = {T_S3,tuser,tdest,tdata[63:40],{16{1'b0}}};
                8'hf0: start_payload = {T_S4,tuser,tdest,tdata[63:32],{8{1'b0}}};
                8'hf8: start_payload = {T_S5,tuser,tdest,tdata[63:24]};
                8'hfc: start_payload = {T_S5,tuser,tdest,tdata[63:24]};
                8'hfe: start_payload = {T_S5,tuser,tdest,tdata[63:24]};
                8'hff: start_payload = {T_S5,tuser,tdest,tdata[63:24]};
                default: start_payload = {T_ERROR,{56{1'b0}}};
            endcase
    endfunction

    function [63:0] end_payload;
        input  [7:0] tkeep;
        input [63:0] tdata;
            case(tkeep)
                8'h00: end_payload = {T_T0,{56{1'b0}}};
                8'h80: end_payload = {T_T1,tdata[63:56],{48{1'b0}}};
                8'hc0: end_payload = {T_T2,tdata[63:48],{40{1'b0}}};
                8'he0: end_payload = {T_T3,tdata[63:40],{32{1'b0}}};
                8'hf0: end_payload = {T_T4,tdata[63:32],{24{1'b0}}};
                8'hf8: end_payload = {T_T5,tdata[63:24],{16{1'b0}}};
                8'hfc: end_payload = {T_T6,tdata[63:16],{8{1'b0}}};
                8'hfe: end_payload = {T_T7,tdata[63:8]};
                default: end_payload = {T_ERROR,{56{1'b0}}};
            endcase
    endfunction

    // Assignments
    assign s_axis_tready  = s_axis_tready_reg;
    assign inject_pause   = !inject_pause_reg && inject_pause_in;
    assign inject_unpause = inject_pause_reg && !inject_pause_in;
    assign load_buf       = s_axis_tready_reg && !s_axis_tready_int;
    assign load_from_buf  = !s_axis_tready_reg && s_axis_tready_int;

    always @(*) begin
        // Defaults
        s_axis_tready_int = 1'b1;
        header_out        = H_CTRL;
        payload_out       = IDLE;
        next_state        = state;

        // Logic
        if(inject_pause || inject_unpause) begin
            s_axis_tready_int = 1'b0;
            header_out        = H_CTRL;
            payload_out       = inject_pause_in ? PAUSE : UNPAUSE;
        end
        else if(pause_in) begin
            s_axis_tready_int = 1'b0;
            header_out        = H_CTRL;
            payload_out       = IDLE;
        end
        else begin
            case(state)
                START: begin
                    if(s_axis_tvalid_reg) begin
                        header_out  = H_CTRL;
                        payload_out = start_payload(s_axis_tkeep_reg,s_axis_tuser_reg,s_axis_tdest_reg,s_axis_tdata_reg);
                        next_state  = s_axis_tkeep_reg[3] ? (s_axis_tlast_reg ? SEND_LAST : SEND_MIDDLE) : START;
                    end
                    else begin
                        header_out  = H_CTRL;
                        payload_out = IDLE;
                        next_state  = START;
                    end
                end
                SEND_MIDDLE: begin
                    if(s_axis_tvalid_reg) begin
                        if(s_axis_tlast_reg) begin
                            if(s_axis_tkeep_reg[3]) begin
                                header_out  = H_DATA;
                                payload_out = {tdata_temp,s_axis_tdata_reg[63:24]};
                                next_state  = SEND_LAST;
                            end
                            else begin
                                header_out  = H_CTRL;
                                payload_out = end_payload({tkeep_temp,s_axis_tkeep_reg[7:3]},{tdata_temp,s_axis_tdata_reg[63:24]});
                                next_state  = s_axis_tkeep_reg[4] ? SEND_LAST : START;
                            end
                        end
                        else begin
                            header_out  = H_DATA;
                            payload_out = {tdata_temp,s_axis_tdata_reg[63:24]};
                            next_state  = SEND_MIDDLE;
                        end
                    end
                    else begin
                        header_out  = H_CTRL;
                        payload_out = IDLE;
                        next_state  = SEND_MIDDLE;
                    end
                end
                SEND_LAST: begin
                    s_axis_tready_int = 1'b0;
                    header_out        = H_CTRL;
                    payload_out       = end_payload({tkeep_temp,{5{1'b0}}},{tdata_temp,{40{1'b0}}});
                    next_state        = START;
                end
            endcase
        end
    end

    // Sequential logic

    // User interface buffers
    always @(posedge clk_in) begin
        if(load_from_buf)begin
            s_axis_tdata_reg  <= s_axis_tdata_buf;
            s_axis_tkeep_reg  <= s_axis_tkeep_buf;
            s_axis_tuser_reg  <= s_axis_tuser_buf;
            s_axis_tdest_reg  <= s_axis_tdest_buf;
            s_axis_tlast_reg  <= s_axis_tlast_buf;
            s_axis_tvalid_reg <= s_axis_tvalid_buf;
        end
        else if(!s_axis_tready_int) begin
            s_axis_tdata_reg  <= s_axis_tdata_reg;
            s_axis_tkeep_reg  <= s_axis_tkeep_reg;
            s_axis_tuser_reg  <= s_axis_tuser_reg;
            s_axis_tdest_reg  <= s_axis_tdest_reg;
            s_axis_tlast_reg  <= s_axis_tlast_reg;
            s_axis_tvalid_reg <= s_axis_tvalid_reg;
        end
        else begin
            s_axis_tdata_reg  <= s_axis_tdata;
            s_axis_tkeep_reg  <= s_axis_tkeep;
            s_axis_tuser_reg  <= s_axis_tuser;
            s_axis_tdest_reg  <= s_axis_tdest;
            s_axis_tlast_reg  <= s_axis_tlast;
            s_axis_tvalid_reg <= s_axis_tvalid;
        end
        s_axis_tready_reg <= s_axis_tready_int;
    end

    // Handshake overflow buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            s_axis_tdata_buf  <= {64{1'b0}};
            s_axis_tkeep_buf  <= {8{1'b0}};
            s_axis_tuser_buf  <= {8{1'b0}};
            s_axis_tdest_buf  <= {8{1'b0}};
            s_axis_tlast_buf  <= {8{1'b0}};
            s_axis_tvalid_buf <= 1'b0;
        end
        else if(load_buf)begin
            s_axis_tdata_buf  <= s_axis_tdata;
            s_axis_tkeep_buf  <= s_axis_tkeep;
            s_axis_tuser_buf  <= s_axis_tuser;
            s_axis_tdest_buf  <= s_axis_tdest;
            s_axis_tlast_buf  <= s_axis_tlast;
            s_axis_tvalid_buf <= s_axis_tvalid;
        end
    end

    // Control buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            inject_pause_reg <= 1'b0;
            pause_reg        <= 1'b0;
        end
        else begin
            inject_pause_reg <= inject_pause_in;
            pause_reg        <= pause_in;
        end
    end

    // Internal buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            tdata_temp <= {24{1'b0}};
            tkeep_temp <= {3{1'b0}};
        end
        else if(s_axis_tvalid_reg) begin
            tdata_temp <= s_axis_tdata_reg[23:0];
            tkeep_temp <= s_axis_tkeep_reg[2:0];
        end
    end

    // State logic
    always @(posedge clk_in) begin
        if(rst_in) state <= START;
        else    state <= next_state;
    end

endmodule
