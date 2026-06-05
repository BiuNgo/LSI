`timescale 1ns / 1ps

module fp32_div(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    input      [31:0] b,
    output reg        valid_out,
    output reg [31:0] y
    );

    localparam IDLE      = 2'd0;
    localparam DIVIDE    = 2'd1;
    localparam NORMALIZE = 2'd2;
    localparam DONE      = 2'd3;

    reg [1:0] state;
    
    reg sign_y;
    reg signed [9:0] exp_true;
    reg signed [9:0] final_exp;
    reg [22:0] final_mant;
    
    reg [48:0] dividend_reg;
    reg [24:0] divisor_reg;
    reg [24:0] quotient_reg;
    reg [4:0]  bit_count;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            valid_out <= 0;
            y         <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        sign_y <= a[31] ^ b[31];
                        
                        if (b[30:0] == 0) begin
                            y <= {a[31] ^ b[31], 8'hFF, 23'b0};
                            state <= DONE;
                        end else if (a[30:0] == 0) begin
                            y <= {a[31] ^ b[31], 31'b0};
                            state <= DONE;
                        end else begin
                            exp_true <= {2'b0, a[30:23]} - {2'b0, b[30:23]} + 10'd127;
                            
                            dividend_reg <= {1'b0, 1'b1, a[22:0], 24'b0}; 
                            divisor_reg  <= {1'b0, 1'b1, b[22:0]};        
                            quotient_reg <= 0;
                            bit_count    <= 25;
                            
                            state <= DIVIDE;
                        end
                    end
                end

                DIVIDE: begin
                    if (bit_count > 0) begin
                        if (dividend_reg[48:24] >= divisor_reg) begin
                            dividend_reg <= { (dividend_reg[48:24] - divisor_reg), dividend_reg[23:0] } << 1;
                            quotient_reg <= (quotient_reg << 1) | 1'b1;
                        end else begin
                            dividend_reg <= dividend_reg << 1;
                            quotient_reg <= quotient_reg << 1;
                        end
                        bit_count <= bit_count - 1;
                    end else begin
                        state <= NORMALIZE;
                    end
                end

                NORMALIZE: begin
                    if (quotient_reg[24]) begin
                        final_exp  = exp_true;
                        final_mant = quotient_reg[23:1];
                    end else begin
                        final_exp  = exp_true - 1;
                        final_mant = quotient_reg[22:0];
                    end

                    if (final_exp <= 0) begin
                        y <= {sign_y, 31'b0};
                    end else if (final_exp >= 255) begin
                        y <= {sign_y, 8'hFF, 23'b0};
                    end else begin
                        y <= {sign_y, final_exp[7:0], final_mant};
                    end
                    
                    state <= DONE;
                end

                DONE: begin
                    valid_out <= 1;
                    state     <= IDLE;
                end
            endcase
        end
    end
endmodule