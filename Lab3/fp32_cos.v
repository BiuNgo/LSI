`timescale 1ns / 1ps

//`include "fp32_add.v"
//`include "fp32_mul.v"
//`include "fp32_div.v"

module fp32_cos(
    input [31:0] a,
    output wire [31:0] y
    );
    
    wire [31:0] z, n1_m, d1_m, n1, d1, n2_m, d2_m, n2, d2;
    
    fp32_mul sqr_x (.a(a), .b(a), .y(z));
    fp32_mul mn1   (.a(32'h3CA98E6B), .b(z), .y(n1_m));
    fp32_add an1   (.a(n1_m), .b(32'hBEE9A9B5), .y(n1));
    fp32_mul md1   (.a(32'h3A61661A), .b(z), .y(d1_m));
    fp32_add ad1   (.a(d1_m), .b(32'h3D32C570), .y(d1));
    fp32_mul mn2   (.a(n1), .b(z), .y(n2_m));
    fp32_add an2   (.a(n2_m), .b(32'h3F800000), .y(n2));
    fp32_mul md2   (.a(d1), .b(z), .y(d2_m));
    fp32_add ad2   (.a(d2_m), .b(32'h3F800000), .y(d2));
    fp32_div out_d (.a(n2), .b(d2), .y(y));
endmodule