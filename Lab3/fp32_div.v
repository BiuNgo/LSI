`timescale 1ns / 1ps

module fp32_div(
    input      [31:0] a,
    input      [31:0] b,
    output reg [31:0] y
    );
    
    reg [8:0] exp_diff;
    reg [47:0] mant_a_shifted;
    reg [23:0] mant_b;
    reg [47:0] mant_div;

    always @(*) begin
        if (b[30:0] == 0) begin
            y = {a[31] ^ b[31], 8'hFF, 23'b0};
        end else if (a[30:0] == 0) begin
            y = {a[31] ^ b[31], 31'b0};
        end else begin
            exp_diff = a[30:23] - b[30:23] + 127;
            mant_a_shifted = {1'b1, a[22:0], 24'b0};
            mant_b = {1'b1, b[22:0]};
            mant_div = mant_a_shifted / mant_b;
            
            if (mant_div[24]) y = {a[31] ^ b[31], exp_diff[7:0], mant_div[23:1]};
            else              y = {a[31] ^ b[31], exp_diff[7:0] - 8'd1, mant_div[22:0]};
        end
    end
endmodule