`timescale 1ns / 1ps

module fp32_mul(
    input      [31:0] a,
    input      [31:0] b,
    output reg [31:0] y
    );
    
    reg [8:0] exp_sum;
    reg [47:0] mant_prod;

    always @(*) begin
        if (a[30:0] == 0 || b[30:0] == 0) begin
            y = {a[31] ^ b[31], 31'b0};
        end else begin
            exp_sum = a[30:23] + b[30:23] - 127;
            mant_prod = {1'b1, a[22:0]} * {1'b1, b[22:0]};
            if (mant_prod[47]) y = {a[31] ^ b[31], exp_sum[7:0] + 8'd1, mant_prod[46:24]};
            else               y = {a[31] ^ b[31], exp_sum[7:0], mant_prod[45:23]};
        end
    end
endmodule