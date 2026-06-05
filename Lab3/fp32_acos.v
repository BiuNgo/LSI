`timescale 1ns / 1ps

module fp32_acos(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    output reg        valid_out,
    output reg [31:0] y
    );

    reg         mul_n_v_in, mul_d_v_in, add_n_v_in, add_d_v_in, div_v_in;
    wire        mul_n_v_out, mul_d_v_out, add_n_v_out, add_d_v_out, div_v_out;
    
    reg  [31:0] mul_n_a, mul_n_b, mul_d_a, mul_d_b;
    reg  [31:0] add_n_a, add_n_b, add_d_a, add_d_b;
    reg  [31:0] div_a, div_b;
    
    wire [31:0] mul_n_y, mul_d_y, add_n_y, add_d_y, div_y;

    fp32_mul mul_n_inst (.clk(clk), .rst(rst), .valid_in(mul_n_v_in), .a(mul_n_a), .b(mul_n_b), .valid_out(mul_n_v_out), .y(mul_n_y));
    fp32_mul mul_d_inst (.clk(clk), .rst(rst), .valid_in(mul_d_v_in), .a(mul_d_a), .b(mul_d_b), .valid_out(mul_d_v_out), .y(mul_d_y));

    fp32_add add_n_inst (.clk(clk), .rst(rst), .valid_in(add_n_v_in), .a(add_n_a), .b(add_n_b), .valid_out(add_n_v_out), .y(add_n_y));
    fp32_add add_d_inst (.clk(clk), .rst(rst), .valid_in(add_d_v_in), .a(add_d_a), .b(add_d_b), .valid_out(add_d_v_out), .y(add_d_y));

    fp32_div div_inst (.clk(clk), .rst(rst), .valid_in(div_v_in), .a(div_a), .b(div_b), .valid_out(div_v_out), .y(div_y));

    localparam IDLE       = 3'd0;
    localparam WAIT_X2    = 3'd1;
    localparam WAIT_TERMS = 3'd2;
    localparam WAIT_SUMS  = 3'd3;
    localparam WAIT_DIV   = 3'd4;
    localparam WAIT_ASIN  = 3'd5;
    localparam WAIT_ACOS  = 3'd6;
    localparam DONE       = 3'd7;

    reg [2:0]  state;
    reg [31:0] a_reg;

    always @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            valid_out  <= 0;
            y          <= 0;
            mul_n_v_in <= 0; mul_d_v_in <= 0;
            add_n_v_in <= 0; add_d_v_in <= 0;
            div_v_in   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        if (a == 32'h3F800000) begin
                            y <= 32'h00000000;
                            state <= DONE;
                        end else if (a == 32'hBF800000) begin
                            y <= 32'h40490FDB;
                            state <= DONE;
                        end else begin
                            a_reg      <= a;
                            
                            mul_n_a    <= a;
                            mul_n_b    <= a;
                            mul_n_v_in <= 1;
                            state      <= WAIT_X2;
                        end
                    end
                end

                WAIT_X2: begin
                    mul_n_v_in <= 0;
                    if (mul_n_v_out) begin
                        mul_n_a    <= mul_n_y;
                        mul_n_b    <= 32'hBE2E147B;
                        mul_n_v_in <= 1;

                        mul_d_a    <= mul_n_y;
                        mul_d_b    <= 32'hBEA8F5C3;
                        mul_d_v_in <= 1;
                        
                        state <= WAIT_TERMS;
                    end
                end

                WAIT_TERMS: begin
                    mul_n_v_in <= 0; mul_d_v_in <= 0;
                    if (mul_n_v_out) begin
                        add_n_a    <= 32'h3F800000;
                        add_n_b    <= mul_n_y;
                        add_n_v_in <= 1;

                        add_d_a    <= 32'h3F800000;
                        add_d_b    <= mul_d_y;
                        add_d_v_in <= 1;

                        state <= WAIT_SUMS;
                    end
                end

                WAIT_SUMS: begin
                    add_n_v_in <= 0; add_d_v_in <= 0;
                    if (add_n_v_out) begin
                        div_a    <= add_n_y;
                        div_b    <= add_d_y;
                        div_v_in <= 1;
                        state    <= WAIT_DIV;
                    end
                end

                WAIT_DIV: begin
                    div_v_in <= 0;
                    if (div_v_out) begin
                        mul_n_a    <= a_reg;
                        mul_n_b    <= div_y;
                        mul_n_v_in <= 1;
                        state      <= WAIT_ASIN;
                    end
                end

                WAIT_ASIN: begin
                    mul_n_v_in <= 0;
                    if (mul_n_v_out) begin
                        add_n_a    <= 32'h3FC90FDB;
                        add_n_b    <= {~mul_n_y[31], mul_n_y[30:0]};
                        add_n_v_in <= 1;
                        state      <= WAIT_ACOS;
                    end
                end

                WAIT_ACOS: begin
                    add_n_v_in <= 0;
                    if (add_n_v_out) begin
                        y     <= add_n_y;
                        state <= DONE;
                    end
                end

                DONE: begin
                    valid_out <= 1;
                    state     <= IDLE;
                end
            endcase
        end
    end
endmodule