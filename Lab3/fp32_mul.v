`timescale 1ns / 1ps

module fp32_mul(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    input      [31:0] b,
    output reg        valid_out,
    output reg [31:0] y
    );
    
    reg s1_valid, s1_is_zero;
    reg s1_sign_y;
    reg signed [9:0] s1_exp_true;
    reg [47:0] s1_mant_prod;

    always @(posedge clk) begin
        if (rst) s1_valid <= 0;
        else s1_valid <= valid_in;

        if (a[30:0] == 0 || b[30:0] == 0) begin
            s1_is_zero <= 1;
            s1_sign_y <= a[31] ^ b[31];
        end else begin
            s1_is_zero <= 0;
            s1_sign_y <= a[31] ^ b[31];
            s1_exp_true <= {2'b0, a[30:23]} + {2'b0, b[30:23]} - 10'd127;
            s1_mant_prod <= {1'b1, a[22:0]} * {1'b1, b[22:0]};
        end
    end

    reg signed [9:0] final_exp;
    reg norm_shift;

    always @(posedge clk) begin
        if (rst) valid_out <= 0;
        else valid_out <= s1_valid;

        if (s1_is_zero) begin
            y <= {s1_sign_y, 31'b0};
        end else begin
            norm_shift = s1_mant_prod[47];
            final_exp = s1_exp_true + norm_shift;

            if (final_exp <= 0) begin
                y <= {s1_sign_y, 31'b0};
            end else if (final_exp >= 255) begin
                y <= {s1_sign_y, 8'hFF, 23'b0};
            end else begin
                if (norm_shift) y <= {s1_sign_y, final_exp[7:0], s1_mant_prod[46:24]};
                else            y <= {s1_sign_y, final_exp[7:0], s1_mant_prod[45:23]};
            end
        end
    end
endmodule