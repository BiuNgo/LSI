`timescale 1ns / 1ps

module fp32_cbrt(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    output reg        valid_out,
    output reg [31:0] y
    );

    reg [31:0] a_reg;

    wire [31:0] abs_a = {1'b0, a_reg[30:0]};
    
    wire [63:0] div3_mult  = abs_a * 64'h0000000055555556;
    wire [31:0] abs_a_div3 = div3_mult[63:32];
    
    wire [31:0] guess_raw = abs_a_div3 + 32'h2A5119F9;
    wire [31:0] guess     = {a_reg[31], guess_raw[30:0]};

    reg         sq_in_v, x2_in_v, div_in_v, add_in_v, final_in_v;
    wire        sq_out_v, x2_out_v, div_out_v, add_out_v, final_out_v;
    wire [31:0] guess_sq, guess_x2, a_div, nr_sum, cbrt_out;
    
    reg [31:0] sq_a, x2_a, div_a, div_b, add_a, add_b, final_a;

    fp32_mul sq_inst (
        .clk(clk), .rst(rst), .valid_in(sq_in_v),
        .a(sq_a), .b(sq_a), .valid_out(sq_out_v), .y(guess_sq)
    );
    
    fp32_mul x2_inst (
        .clk(clk), .rst(rst), .valid_in(x2_in_v),
        .a(x2_a), .b(32'h40000000), .valid_out(x2_out_v), .y(guess_x2)
    );

    fp32_div div_inst (
        .clk(clk), .rst(rst), .valid_in(div_in_v),
        .a(div_a), .b(div_b), .valid_out(div_out_v), .y(a_div)
    );

    fp32_add add_inst (
        .clk(clk), .rst(rst), .valid_in(add_in_v),
        .a(add_a), .b(add_b), .valid_out(add_out_v), .y(nr_sum)
    );

    fp32_mul final_mul (
        .clk(clk), .rst(rst), .valid_in(final_in_v),
        .a(final_a), .b(32'h3EAAAAAB), .valid_out(final_out_v), .y(cbrt_out)
    );

    localparam IDLE           = 3'd0;
    localparam INIT           = 3'd1;
    localparam WAIT_SQ_X2     = 3'd2;
    localparam WAIT_DIV       = 3'd3;
    localparam WAIT_ADD       = 3'd4;
    localparam WAIT_FINAL_MUL = 3'd5;
    localparam DONE           = 3'd6;

    reg [2:0] state;
    reg [1:0] iter_count;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            valid_out  <= 0;
            y          <= 0;
            sq_in_v    <= 0;
            x2_in_v    <= 0;
            div_in_v   <= 0;
            add_in_v   <= 0;
            final_in_v <= 0;
            iter_count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        if (a[30:0] == 0) begin
                            y     <= a;
                            state <= DONE;
                        end else begin
                            a_reg <= a;
                            state <= INIT;
                        end
                    end
                end

                INIT: begin
                    iter_count <= 0;
                    
                    sq_a    <= guess;
                    x2_a    <= guess;
                    sq_in_v <= 1;
                    x2_in_v <= 1;
                    
                    div_a   <= a_reg; 
                    
                    state   <= WAIT_SQ_X2;
                end

                WAIT_SQ_X2: begin
                    sq_in_v <= 0;
                    x2_in_v <= 0;
                    if (sq_out_v) begin
                        add_a    <= guess_x2;
                        div_b    <= guess_sq;
                        div_in_v <= 1;
                        state    <= WAIT_DIV;
                    end
                end

                WAIT_DIV: begin
                    div_in_v <= 0;
                    if (div_out_v) begin
                        add_b    <= a_div;
                        add_in_v <= 1;
                        state    <= WAIT_ADD;
                    end
                end

                WAIT_ADD: begin
                    add_in_v <= 0;
                    if (add_out_v) begin
                        final_a    <= nr_sum;
                        final_in_v <= 1;
                        state      <= WAIT_FINAL_MUL;
                    end
                end

                WAIT_FINAL_MUL: begin
                    final_in_v <= 0;
                    if (final_out_v) begin
                        if (iter_count == 2'd2) begin
                            y     <= cbrt_out;
                            state <= DONE;
                        end else begin
                            iter_count <= iter_count + 1;
                            
                            sq_a    <= cbrt_out;
                            x2_a    <= cbrt_out;
                            sq_in_v <= 1;
                            x2_in_v <= 1;
                            
                            state   <= WAIT_SQ_X2;
                        end
                    end
                end

                DONE: begin
                    valid_out <= 1;
                    state     <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule