`timescale 1ns / 1ps

module fp32_sqrt(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    output reg        valid_out,
    output reg [31:0] y
    );
    
    reg         div_in_valid, add_in_valid, mul_in_valid;
    wire        div_out_valid, add_out_valid, mul_out_valid;
    wire [31:0] div_out, add_out, mul_out;
    
    reg  [31:0] div_a, div_b, add_a, add_b, mul_a, mul_b;

    fp32_div div_step (
        .clk(clk), .rst(rst), .valid_in(div_in_valid),
        .a(div_a), .b(div_b), .valid_out(div_out_valid), .y(div_out)
    );
    
    fp32_add add_step (
        .clk(clk), .rst(rst), .valid_in(add_in_valid),
        .a(add_a), .b(add_b), .valid_out(add_out_valid), .y(add_out)
    );
    
    fp32_mul mul_step (
        .clk(clk), .rst(rst), .valid_in(mul_in_valid),
        .a(mul_a), .b(mul_b), .valid_out(mul_out_valid), .y(mul_out)
    );

    localparam IDLE      = 3'd0;
    localparam INIT      = 3'd1;
    localparam WAIT_DIV  = 3'd2;
    localparam WAIT_ADD  = 3'd3;
    localparam WAIT_MUL  = 3'd4;
    localparam DONE      = 3'd5;

    reg [2:0]  state;
    reg [31:0] a_reg;
    reg [31:0] current_guess;
    reg [1:0]  iter_count;

    always @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            valid_out    <= 0;
            y            <= 0;
            div_in_valid <= 0;
            add_in_valid <= 0;
            mul_in_valid <= 0;
            iter_count   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        if (a[31] && a[30:0] != 0) begin
                            y     <= 32'h7FC00000;
                            state <= DONE;
                        end else if (a[30:0] == 0) begin
                            y     <= a;
                            state <= DONE;
                        end else begin
                            a_reg <= a;
                            state <= INIT;
                        end
                    end
                end

                INIT: begin
                    current_guess <= (a_reg >> 1) + 32'h1FBCF800;
                    iter_count    <= 0;
                    
                    div_a         <= a_reg;
                    div_b         <= (a_reg >> 1) + 32'h1FBCF800;
                    div_in_valid  <= 1; 
                    
                    state         <= WAIT_DIV;
                end

                WAIT_DIV: begin
                    div_in_valid <= 0;
                    if (div_out_valid) begin
                        add_a        <= current_guess;
                        add_b        <= div_out;
                        add_in_valid <= 1;
                        state        <= WAIT_ADD;
                    end
                end

                WAIT_ADD: begin
                    add_in_valid <= 0;
                    if (add_out_valid) begin
                        mul_a        <= 32'h3F000000;
                        mul_b        <= add_out;
                        mul_in_valid <= 1;
                        state        <= WAIT_MUL;
                    end
                end

                WAIT_MUL: begin
                    mul_in_valid <= 0;
                    if (mul_out_valid) begin
                        if (iter_count == 2'd2) begin
                            y     <= mul_out;
                            state <= DONE;
                        end else begin
                            current_guess <= mul_out;
                            iter_count    <= iter_count + 1;
                            
                            div_a         <= a_reg;
                            div_b         <= mul_out;
                            div_in_valid  <= 1;
                            
                            state         <= WAIT_DIV;
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