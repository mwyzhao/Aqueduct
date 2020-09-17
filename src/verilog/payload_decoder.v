module payload_decoder(
    input             clk_in,
    input             rst_in,
    input      [63:0] payload_in,
    input       [1:0] header_in,
    input             valid_in,
    output     [63:0] m_axis_tdata,
    output      [7:0] m_axis_tkeep,
    output      [7:0] m_axis_tuser,
    output      [7:0] m_axis_tdest,
    output            m_axis_tlast,
    output            m_axis_tvalid,
    output            m_error,
    output            pause_out,
    output            unpause_out,
    output      [7:0] pause_src_out
);

    // Signals and parameters

    // Payload interface buffers
    reg [63:0] payload_reg;
    reg  [1:0] header_reg;
    reg        valid_reg;

    // User interface buffers
    reg [63:0] m_axis_tdata_reg;
    reg  [7:0] m_axis_tkeep_reg;
    reg  [7:0] m_axis_tuser_reg;
    reg  [7:0] m_axis_tdest_reg;
    reg        m_axis_tlast_reg;
    reg        m_axis_tvalid_reg;
    reg        m_error_reg;

    // Control interface buffers
    reg        pause_reg;
    reg        unpause_reg;
    reg        pause_src_reg;

    // User interface signals
    reg [63:0] m_axis_tdata_int;
    reg  [7:0] m_axis_tkeep_int;
    reg  [7:0] m_axis_tuser_int;
    reg  [7:0] m_axis_tdest_int;
    reg        m_axis_tlast_int;
    reg        m_axis_tvalid_int;
    reg        m_error_int;

    // Control interface signals
    reg        pause_int;
    reg        unpause_int;
    reg        pause_src_int;

    // Control signals
    reg        load_buf;

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
    
    // State parameters
    localparam START       = 4'b0001;
    localparam SEND_MIDDLE = 4'b0010;
    localparam SEND_LAST   = 4'b0100;
    localparam END         = 4'b1000;

    reg  [3:0] state;
    reg  [3:0] next_state;
    
    // Combinational logic

    // Assign outputs
    assign m_axis_tdata  = m_axis_tdata_reg;
    assign m_axis_tkeep  = m_axis_tkeep_reg;
    assign m_axis_tuser  = m_axis_tuser_reg;
    assign m_axis_tdest  = m_axis_tdest_reg;
    assign m_axis_tlast  = m_axis_tlast_reg;
    assign m_axis_tvalid = m_axis_tvalid_reg;
    assign m_error       = m_error_reg;
    assign pause_out     = pause_reg;
    assign unpause_out   = unpause_reg;
    assign pause_src_out = pause_src_reg;

    always @(*) begin
        // Defaults
        load_buf          = 1'b1;
        m_axis_tdata_int  = {64{1'b0}};
        m_axis_tkeep_int  = {8{1'b0}};
        m_axis_tuser_int  = m_axis_tuser_reg;
        m_axis_tdest_int  = m_axis_tdest_reg;
        m_axis_tlast_int  = 1'b0;
        m_axis_tvalid_int = 1'b0;
        m_error_int       = 1'b0;
        pause_int         = 1'b0;
        unpause_int       = 1'b0;
        pause_src_int     = {8{1'b0}};
        next_state        = state;
        
        // Logic
        if(valid_reg) begin
            if(header_reg == H_CTRL && (payload_reg[63:56] == T_PAUSE || payload_reg[63:56] == T_IDLE)) begin
                case(payload_reg[63:56])
                    T_PAUSE: begin
                        pause_int     = &payload_reg[39:8];
                        unpause_int   = !(&payload_reg[39:8]);
                        pause_src_int = payload_reg[55:48];
                    end
                    T_IDLE: begin
                        ; // defaults
                    end
                endcase
            end
            else begin
                case(state)
                    START: begin
                        case({header_reg,payload_reg[63:56]})
                            {H_CTRL,T_ERROR}: begin
                                m_error_int       = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_S1}: begin
                                m_axis_tdata_int  = {payload_reg[39:32],{56{1'b0}}};
                                m_axis_tkeep_int  = 8'h80;
                                m_axis_tuser_int  = payload_reg[55:48];
                                m_axis_tdest_int  = payload_reg[47:40];
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_S2}: begin
                                m_axis_tdata_int  = {payload_reg[39:24],{48{1'b0}}};
                                m_axis_tkeep_int  = 8'hc0;
                                m_axis_tuser_int  = payload_reg[55:48];
                                m_axis_tdest_int  = payload_reg[47:40];
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_S3}: begin
                                m_axis_tdata_int  = {payload_reg[39:16],{40{1'b0}}};
                                m_axis_tkeep_int  = 8'he0;
                                m_axis_tuser_int  = payload_reg[55:48];
                                m_axis_tdest_int  = payload_reg[47:40];
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_S4}: begin
                                m_axis_tdata_int  = {payload_reg[39:8],{32{1'b0}}};
                                m_axis_tkeep_int  = 8'hf0;
                                m_axis_tuser_int  = payload_reg[55:48];
                                m_axis_tdest_int  = payload_reg[47:40];
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_S5}: begin
                                if(valid_in) begin
                                    if(header_in == H_DATA) begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[63:40]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tuser_int  = payload_reg[55:48];
                                        m_axis_tdest_int  = payload_reg[47:40];
                                        m_axis_tlast_int  = 1'b0;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = SEND_MIDDLE;
                                    end
                                    else begin
                                        case({header_in,payload_in[63:56]})
                                            {H_CTRL,T_ERROR}: begin
                                                m_error_int       = 1'b1;
                                                next_state        = START;
                                            end
                                            {H_CTRL,T_PAUSE}: begin
                                                load_buf          = 1'b0;
                                                pause_int         = &payload_in[39:8];
                                                unpause_int       = !(&payload_in[39:8]);
                                                pause_src_int     = payload_in[55:48];
                                                next_state        = START;
                                            end
                                            {H_CTRL,T_IDLE}: begin
                                                load_buf          = 1'b0;
                                                next_state        = START;
                                            end
                                            {H_CTRL,T_T0}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],{24{1'b0}}};
                                                m_axis_tkeep_int  = 8'hf8;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b1;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = END;
                                            end
                                            {H_CTRL,T_T1}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:48],{16{1'b0}}};
                                                m_axis_tkeep_int  = 8'hfc;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b1;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = END;
                                            end
                                            {H_CTRL,T_T2}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:40],{8{1'b0}}};
                                                m_axis_tkeep_int  = 8'hfe;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b1;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = END;
                                            end
                                            {H_CTRL,T_T3}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                                m_axis_tkeep_int  = 8'hff;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b1;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = END;
                                            end
                                            {H_CTRL,T_T4}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                                m_axis_tkeep_int  = 8'hff;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b0;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = SEND_LAST;
                                            end
                                            {H_CTRL,T_T5}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                                m_axis_tkeep_int  = 8'hff;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b0;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = SEND_LAST;
                                            end
                                            {H_CTRL,T_T6}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                                m_axis_tkeep_int  = 8'hff;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b0;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = SEND_LAST;
                                            end
                                            {H_CTRL,T_T7}: begin
                                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                                m_axis_tkeep_int  = 8'hff;
                                                m_axis_tuser_int  = payload_reg[55:48];
                                                m_axis_tdest_int  = payload_reg[47:40];
                                                m_axis_tlast_int  = 1'b0;
                                                m_axis_tvalid_int = 1'b1;
                                                next_state        = SEND_LAST;
                                            end
                                            default: begin
                                                m_error_int = 1'b1;
                                                next_state  = START;
                                            end
                                        endcase
                                    end
                                end
                                else begin
                                    load_buf   = 1'b0;
                                    next_state = START;
                                end
                            end
                            default: begin
                                m_error_int = 1'b1;
                                next_state  = START;
                            end
                        endcase
                    end
                    SEND_MIDDLE: begin
                        if(valid_in) begin
                            if(header_in == H_DATA) begin
                                m_axis_tdata_int  = {payload_reg[39:0],payload_in[63:40]};
                                m_axis_tkeep_int  = 8'hff;
                                m_axis_tuser_int  = payload_reg[55:48];
                                m_axis_tdest_int  = payload_reg[47:40];
                                m_axis_tlast_int  = 1'b0;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = SEND_MIDDLE;
                            end
                            else begin
                                case({header_in,payload_in[63:56]})
                                    {H_CTRL,T_ERROR}: begin
                                        m_error_int       = 1'b1;
                                        next_state        = START;
                                    end
                                    {H_CTRL,T_PAUSE}: begin
                                        load_buf          = 1'b0;
                                        pause_int         = &payload_in[39:8];
                                        unpause_int       = !(&payload_in[39:8]);
                                        pause_src_int     = payload_in[55:48];
                                        next_state        = SEND_MIDDLE;
                                    end
                                    {H_CTRL,T_IDLE}: begin
                                        load_buf          = 1'b0;
                                        next_state        = SEND_MIDDLE;
                                    end
                                    {H_CTRL,T_T0}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],{24{1'b0}}};
                                        m_axis_tkeep_int  = 8'hf8;
                                        m_axis_tlast_int  = 1'b1;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = END;
                                    end
                                    {H_CTRL,T_T1}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:48],{16{1'b0}}};
                                        m_axis_tkeep_int  = 8'hfc;
                                        m_axis_tlast_int  = 1'b1;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = END;
                                    end
                                    {H_CTRL,T_T2}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:40],{8{1'b0}}};
                                        m_axis_tkeep_int  = 8'hfe;
                                        m_axis_tlast_int  = 1'b1;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = END;
                                    end
                                    {H_CTRL,T_T3}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tlast_int  = 1'b1;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = END;
                                    end
                                    {H_CTRL,T_T4}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tlast_int  = 1'b0;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = SEND_LAST;
                                    end
                                    {H_CTRL,T_T5}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tlast_int  = 1'b0;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = SEND_LAST;
                                    end
                                    {H_CTRL,T_T6}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tlast_int  = 1'b0;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = SEND_LAST;
                                    end
                                    {H_CTRL,T_T7}: begin
                                        m_axis_tdata_int  = {payload_reg[39:0],payload_in[55:32]};
                                        m_axis_tkeep_int  = 8'hff;
                                        m_axis_tlast_int  = 1'b0;
                                        m_axis_tvalid_int = 1'b1;
                                        next_state        = SEND_LAST;
                                    end
                                    default: begin
                                        m_error_int = 1'b1;
                                        next_state  = START;
                                    end
                                endcase
                            end
                        end
                        else begin
                            load_buf   = 1'b0;
                            next_state = SEND_MIDDLE;
                        end
                    end
                    SEND_LAST: begin
                        case({header_reg,payload_reg[63:56]})
                            {H_CTRL,T_T4}: begin
                                m_axis_tdata_int  = {payload_reg[31:24],{56{1'b0}}};
                                m_axis_tkeep_int  = 8'h80;
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_T5}: begin
                                m_axis_tdata_int  = {payload_reg[31:16],{48{1'b0}}};
                                m_axis_tkeep_int  = 8'hc0;
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_T6}: begin
                                m_axis_tdata_int  = {payload_reg[31:8],{40{1'b0}}};
                                m_axis_tkeep_int  = 8'he0;
                                m_axis_tlast_int  = 1'b1;
                                m_axis_tvalid_int = 1'b1;
                                next_state        = START;
                            end
                            {H_CTRL,T_T7}: begin
                                if(valid_in) begin
                                    case({header_in,payload_in[63:56]})
                                        {H_CTRL,T_ERROR}: begin
                                            m_error_int       = 1'b1;
                                            next_state        = START;
                                        end
                                        {H_CTRL,T_PAUSE}: begin
                                            load_buf          = 1'b0;
                                            pause_int         = &payload_in[39:8];
                                            unpause_int       = !(&payload_in[39:8]);
                                            pause_src_int     = payload_in[55:48];
                                            next_state        = SEND_LAST;
                                        end
                                        {H_CTRL,T_IDLE}: begin
                                            load_buf          = 1'b0;
                                            next_state        = SEND_LAST;
                                        end
                                        {H_CTRL,T_T0}: begin
                                            m_axis_tdata_int  = {payload_reg[31:0],{32{1'b0}}};
                                            m_axis_tkeep_int  = 8'hf0;
                                            m_axis_tlast_int  = 1'b1;
                                            m_axis_tvalid_int = 1'b1;
                                            next_state        = END;
                                        end
                                        default: begin
                                            m_error_int = 1'b1;
                                            next_state  = START;
                                        end
                                    endcase
                                end
                                else begin
                                    load_buf   = 1'b0;
                                    next_state = SEND_LAST;
                                end
                            end
                            default: begin
                                m_error_int = 1'b1;
                                next_state  = START;
                            end
                        endcase
                    end
                    END: begin
                        m_axis_tvalid_int = 1'b0;
                        next_state        = START;
                    end
                endcase
            end
        end
    end

    // Sequential logic

    // User interface buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            m_axis_tdata_reg  <= {64{1'b0}};
            m_axis_tkeep_reg  <= {8{1'b0}};
            m_axis_tuser_reg  <= {8{1'b0}};
            m_axis_tdest_reg  <= {8{1'b0}};
            m_axis_tlast_reg  <= {8{1'b0}};
            m_axis_tvalid_reg <= 1'b0;
            m_error_reg       <= 1'b0;
        end
        else begin
            m_axis_tdata_reg  <= m_axis_tdata_int;
            m_axis_tkeep_reg  <= m_axis_tkeep_int;
            m_axis_tuser_reg  <= m_axis_tuser_int;
            m_axis_tdest_reg  <= m_axis_tdest_int;
            m_axis_tlast_reg  <= m_axis_tlast_int;
            m_axis_tvalid_reg <= m_axis_tvalid_int;
            m_error_reg       <= m_error_int;
        end
    end

    // Payload buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            payload_reg <= {64{1'b0}};
            header_reg  <= {2{1'b0}};
            valid_reg   <= 1'b0;
        end
        else if(load_buf) begin
            payload_reg <= payload_in;
            header_reg  <= header_in;
            valid_reg   <= valid_in;
        end
    end

    // Control buffers
    always @(posedge clk_in) begin
        if(rst_in) begin
            pause_reg     <= 1'b0;
            unpause_reg   <= 1'b0;
            pause_src_reg <= {8{1'b0}};
        end
        else begin
            pause_reg     <= pause_int;
            unpause_reg   <= unpause_int;
            pause_src_reg <= pause_src_int;
        end
    end

    // State logic
    always @(posedge clk_in) begin
        if(rst_in) state <= START;
        else       state <= next_state;
    end

endmodule
