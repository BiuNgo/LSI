`timescale 1ns / 1ps

//`include "fp32_add.v"
//`include "fp32_mul.v"
//`include "fp32_div.v"

module fp32_acos(
    input [31:0] a,
    output wire [31:0] y
    );
    
    wire [31:0] x2, num_term, den_term, num_sum, den_sum, rational, arcsin, arcsin_n;
    wire [31:0] acos_approx;
    
    fp32_mul m_x2 (.a(a), .b(a), .y(x2));
    fp32_mul m_num (.a(x2), .b(32'hBE2E147B), .y(num_term));
    fp32_add a_num (.a(32'h3F800000), .b(num_term), .y(num_sum));
    fp32_mul m_den (.a(x2), .b(32'hBEA8F5C3), .y(den_term));
    fp32_add a_den (.a(32'h3F800000), .b(den_term), .y(den_sum));
    fp32_div d_rat (.a(num_sum), .b(den_sum), .y(rational));
    fp32_mul m_asi (.a(a), .b(rational), .y(arcsin));
    
    assign arcsin_n = {~arcsin[31], arcsin[30:0]};
    fp32_add a_aco (.a(32'h3FC90FDB), .b(arcsin_n), .y(acos_approx));
    
    assign y = (a == 32'h3F800000) ? 32'h00000000 :
               (a == 32'hBF800000) ? 32'h40490FDB :
               acos_approx;
endmodule