`timescale 1ns / 1ps

//`include "fp32_add.v"
//`include "fp32_mul.v"
//`include "fp32_div.v"

module fp32_sqrt(
    input [31:0] a,
    output wire [31:0] y
    );
    
    wire [31:0] guess_raw = (a >> 1) + 32'h1FBCF800;
    wire [31:0] div_out, add_out, sqrt_out;
    
    fp32_div div_step (.a(a), .b(guess_raw), .y(div_out));
    fp32_add add_step (.a(guess_raw), .b(div_out), .y(add_out));
    fp32_mul mul_step (.a(32'h3F000000), .b(add_out), .y(sqrt_out));

    assign y = (a[31] && a[30:0] != 0) ? 32'h7FC00000 : (a[30:0] == 0) ? 0 : sqrt_out;
endmodule