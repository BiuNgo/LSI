`timescale 1ns / 1ps

module fp32_add(
    input      [31:0] a,
    input      [31:0] b,
    output reg [31:0] y
    );
    
    reg sign_a, sign_b, sign_y;
    reg [7:0] exp_a, exp_b, exp_y;
    reg [23:0] mant_a, mant_b, mant_shifted;
    reg [24:0] mant_sum;
    reg [7:0] exp_diff;
    integer i;

    always @(*) begin
        if (a[30:0] == 0 && b[30:0] == 0) begin
            y = {a[31] & b[31], 31'b0};
        end else if (a[30:0] == 0) begin
            y = b;
        end else if (b[30:0] == 0) begin
            y = a;
        end else begin
            sign_a = a[31];
            sign_b = b[31];
            exp_a = a[30:23];
            exp_b = b[30:23];
            mant_a = {1'b1, a[22:0]};
            mant_b = {1'b1, b[22:0]};

            if (exp_a > exp_b || (exp_a == exp_b && mant_a >= mant_b)) begin
                exp_diff = exp_a - exp_b;
                mant_shifted = mant_b >> exp_diff;
                exp_y = exp_a;
                sign_y = sign_a;
                mant_sum = (sign_a == sign_b) ? (mant_a + mant_shifted) : (mant_a - mant_shifted);
            end else begin
                exp_diff = exp_b - exp_a;
                mant_shifted = mant_a >> exp_diff;
                exp_y = exp_b;
                sign_y = sign_b;
                mant_sum = (sign_a == sign_b) ? (mant_b + mant_shifted) : (mant_b - mant_shifted);
            end

            if (mant_sum[24]) begin
                mant_sum = mant_sum >> 1;
                exp_y = exp_y + 1;
            end else begin
                for (i = 0; i < 24; i = i + 1) begin
                    if (!mant_sum[23] && mant_sum != 0) begin
                        mant_sum = mant_sum << 1;
                        exp_y = exp_y - 1;
                    end
                end
            end
            
            y = (mant_sum == 0) ? 32'b0 : {sign_y, exp_y, mant_sum[22:0]};
        end
    end
endmodule