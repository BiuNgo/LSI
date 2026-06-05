`timescale 1ns / 1ps

module fp32_add(
    input             clk,
    input             rst,
    input             valid_in,
    input      [31:0] a,
    input      [31:0] b,
    output reg        valid_out,
    output reg [31:0] y
    );
    
    reg s1_valid, s1_sign_y, s1_same_sign, s1_is_special;
    reg [7:0] s1_exp_y;
    reg [24:0] s1_mant_large, s1_mant_shifted;
    reg [31:0] s1_special_res;

    always @(posedge clk) begin
        if (rst) s1_valid <= 0;
        else s1_valid <= valid_in;

        if (a[30:0] == 0 && b[30:0] == 0) begin
            s1_is_special <= 1;
            s1_special_res <= {a[31] & b[31], 31'b0};
        end else if (a[30:0] == 0) begin
            s1_is_special <= 1;
            s1_special_res <= b;
        end else if (b[30:0] == 0) begin
            s1_is_special <= 1;
            s1_special_res <= a;
        end else begin
            s1_is_special <= 0;
            s1_same_sign <= (a[31] == b[31]);
            
            if (a[30:23] > b[30:23] || (a[30:23] == b[30:23] && a[22:0] >= b[22:0])) begin
                s1_exp_y <= a[30:23];
                s1_sign_y <= a[31];
                s1_mant_large <= {2'b01, a[22:0]};
                s1_mant_shifted <= {2'b01, b[22:0]} >> (a[30:23] - b[30:23]);
            end else begin
                s1_exp_y <= b[30:23];
                s1_sign_y <= b[31];
                s1_mant_large <= {2'b01, b[22:0]};
                s1_mant_shifted <= {2'b01, a[22:0]} >> (b[30:23] - a[30:23]);
            end
        end
    end

    reg s2_valid, s2_sign_y, s2_is_special;
    reg [7:0] s2_exp_y;
    reg [24:0] s2_mant_sum;
    reg [31:0] s2_special_res;

    always @(posedge clk) begin
        if (rst) s2_valid <= 0;
        else s2_valid <= s1_valid;

        s2_is_special <= s1_is_special;
        s2_special_res <= s1_special_res;
        s2_sign_y <= s1_sign_y;
        s2_exp_y <= s1_exp_y;

        if (s1_same_sign) s2_mant_sum <= s1_mant_large + s1_mant_shifted;
        else              s2_mant_sum <= s1_mant_large - s1_mant_shifted;
    end

    reg [4:0] shift_amt;
    reg [24:0] mant_norm;
    reg [7:0] exp_adj;

    always @(posedge clk) begin
        if (rst) valid_out <= 0;
        else valid_out <= s2_valid;

        if (s2_is_special) begin
            y <= s2_special_res;
        end else begin
            if (s2_mant_sum[24]) shift_amt = 0;
            else if (s2_mant_sum[23]) shift_amt = 0;
            else if (s2_mant_sum[22]) shift_amt = 1;
            else if (s2_mant_sum[21]) shift_amt = 2;
            else if (s2_mant_sum[20]) shift_amt = 3;
            else if (s2_mant_sum[19]) shift_amt = 4;
            else if (s2_mant_sum[18]) shift_amt = 5;
            else if (s2_mant_sum[17]) shift_amt = 6;
            else if (s2_mant_sum[16]) shift_amt = 7;
            else if (s2_mant_sum[15]) shift_amt = 8;
            else if (s2_mant_sum[14]) shift_amt = 9;
            else if (s2_mant_sum[13]) shift_amt = 10;
            else if (s2_mant_sum[12]) shift_amt = 11;
            else if (s2_mant_sum[11]) shift_amt = 12;
            else if (s2_mant_sum[10]) shift_amt = 13;
            else if (s2_mant_sum[9])  shift_amt = 14;
            else if (s2_mant_sum[8])  shift_amt = 15;
            else if (s2_mant_sum[7])  shift_amt = 16;
            else if (s2_mant_sum[6])  shift_amt = 17;
            else if (s2_mant_sum[5])  shift_amt = 18;
            else if (s2_mant_sum[4])  shift_amt = 19;
            else if (s2_mant_sum[3])  shift_amt = 20;
            else if (s2_mant_sum[2])  shift_amt = 21;
            else if (s2_mant_sum[1])  shift_amt = 22;
            else if (s2_mant_sum[0])  shift_amt = 23;
            else shift_amt = 24;

            if (s2_mant_sum == 0) begin
                y <= 32'b0;
            end else if (s2_mant_sum[24]) begin
                y <= {s2_sign_y, s2_exp_y + 8'd1, s2_mant_sum[23:1]};
            end else begin
                mant_norm = s2_mant_sum << shift_amt;
                if (s2_exp_y > shift_amt) begin
                    exp_adj = s2_exp_y - shift_amt;
                    y <= {s2_sign_y, exp_adj, mant_norm[22:0]};
                end else begin
                    y <= 32'b0;
                end
            end
        end
    end
endmodule