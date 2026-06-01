`timescale 1ns / 1ps

//`include "fp32_add.v"
//`include "fp32_mul.v"
//`include "fp32_div.v"

module fp32_cbrt(
    input [31:0] a,
    output wire [31:0] y
    );
    
    wire [31:0] abs_a = {1'b0, a[30:0]};
    wire [31:0] guess_raw = (abs_a / 3) + 32'h2A5119F9;
    wire [31:0] guess = {a[31], guess_raw[30:0]};
    wire [31:0] guess_sq, a_div, guess_x2, nr_sum, cbrt_out;
    
    fp32_mul sq_inst   (.a(guess), .b(guess), .y(guess_sq));
    fp32_div div_inst  (.a(a), .b(guess_sq), .y(a_div));
    fp32_mul x2_inst   (.a(guess), .b(32'h40000000), .y(guess_x2));
    fp32_add add_inst  (.a(guess_x2), .b(a_div), .y(nr_sum));
    fp32_mul final_mul (.a(nr_sum), .b(32'h3EAAAAAB), .y(cbrt_out));
    
    assign y = (a[30:0] == 0) ? a : cbrt_out;
endmodule