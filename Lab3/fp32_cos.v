`timescale 1ns / 1ps

module fp32_cos(
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

    localparam IDLE      = 3'd0;
    localparam WAIT_Z    = 3'd1;
    localparam WAIT_M1   = 3'd2;
    localparam WAIT_A1   = 3'd3;
    localparam WAIT_M2   = 3'd4;
    localparam WAIT_A2   = 3'd5;
    localparam WAIT_DIV  = 3'd6;
    localparam DONE      = 3'd7;

    reg [2:0] state;
    reg [31:0] z_reg;

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
                        if (a[30:0] == 0) begin
                            y <= 32'h3F800000;
                            state <= DONE;
                        end else begin
                            mul_n_a    <= a;
                            mul_n_b    <= a;
                            mul_n_v_in <= 1;
                            state      <= WAIT_Z;
                        end
                    end
                end

                WAIT_Z: begin
                    mul_n_v_in <= 0;
                    if (mul_n_v_out) begin
                        z_reg <= mul_n_y;
                        
                        mul_n_a    <= 32'h3CA98E6B; 
                        mul_n_b    <= mul_n_y; 
                        mul_n_v_in <= 1;

                        mul_d_a    <= 32'h3A61661A; 
                        mul_d_b    <= mul_n_y; 
                        mul_d_v_in <= 1;
                        
                        state <= WAIT_M1;
                    end
                end

                WAIT_M1: begin
                    mul_n_v_in <= 0; mul_d_v_in <= 0;
                    if (mul_n_v_out) begin
                        add_n_a    <= mul_n_y; 
                        add_n_b    <= 32'hBEE9A9B5; 
                        add_n_v_in <= 1;

                        add_d_a    <= mul_d_y; 
                        add_d_b    <= 32'h3D32C570; 
                        add_d_v_in <= 1;

                        state <= WAIT_A1;
                    end
                end

                WAIT_A1: begin
                    add_n_v_in <= 0; add_d_v_in <= 0;
                    if (add_n_v_out) begin
                        mul_n_a    <= add_n_y; 
                        mul_n_b    <= z_reg; 
                        mul_n_v_in <= 1;

                        mul_d_a    <= add_d_y; 
                        mul_d_b    <= z_reg; 
                        mul_d_v_in <= 1;

                        state <= WAIT_M2;
                    end
                end

                WAIT_M2: begin
                    mul_n_v_in <= 0; mul_d_v_in <= 0;
                    if (mul_n_v_out) begin
                        add_n_a    <= mul_n_y; 
                        add_n_b    <= 32'h3F800000; 
                        add_n_v_in <= 1;

                        add_d_a    <= mul_d_y; 
                        add_d_b    <= 32'h3F800000; 
                        add_d_v_in <= 1;

                        state <= WAIT_A2;
                    end
                end

                WAIT_A2: begin
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
                        y     <= div_y;
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