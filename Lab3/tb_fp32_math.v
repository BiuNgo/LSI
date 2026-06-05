`timescale 1ns/1ps

module tb_fp32_math();

    reg clk;
    reg rst;
    
    reg  add_v_in, mul_v_in, div_v_in, sqrt_v_in, cbrt_v_in, acos_v_in, cos_v_in;
    wire add_v_out, mul_v_out, div_v_out, sqrt_v_out, cbrt_v_out, acos_v_out, cos_v_out;

    reg  [31:0] a, b;
    wire [31:0] y_add, y_mul, y_div, y_sqrt, y_cbrt, y_acos, y_cos;

    localparam [31:0] FP_0           = 32'h00000000;
    localparam [31:0] FP_NEG_0       = 32'h80000000;
    localparam [31:0] FP_1           = 32'h3F800000;
    localparam [31:0] FP_NEG_1       = 32'hBF800000;
    localparam [31:0] FP_2           = 32'h40000000;
    localparam [31:0] FP_NEG_2       = 32'hC0000000;
    localparam [31:0] FP_3           = 32'h40400000;
    localparam [31:0] FP_4           = 32'h40800000;
    localparam [31:0] FP_NEG_4       = 32'hC0800000;
    localparam [31:0] FP_8           = 32'h41000000;
    localparam [31:0] FP_NEG_8       = 32'hC1000000;
    localparam [31:0] FP_0_5         = 32'h3F000000;
    localparam [31:0] FP_NEG_0_5     = 32'hBF000000;
    localparam [31:0] FP_0_25        = 32'h3E800000;
    localparam [31:0] FP_0_125       = 32'h3E000000;
    localparam [31:0] FP_0_01        = 32'h3C23D70A;
    localparam [31:0] FP_10          = 32'h41200000;
    localparam [31:0] FP_27          = 32'h41D80000;
    localparam [31:0] FP_NEG_27      = 32'hC1D80000;
    localparam [31:0] FP_100         = 32'h42C80000;
    localparam [31:0] FP_NEG_100     = 32'hC2C80000;
    localparam [31:0] FP_PI          = 32'h40490FDB;
    localparam [31:0] FP_NEG_PI      = 32'hC0490FDB;
    localparam [31:0] FP_PI_HALF     = 32'h3FC90FDB; 
    localparam [31:0] FP_NEG_PI_HALF = 32'hBFC90FDB;

    localparam [31:0] FP_INF     = 32'h7F800000;
    localparam [31:0] FP_NEG_INF = 32'hFF800000;
    localparam [31:0] FP_NAN     = 32'h7FC00000;

    integer tests_passed = 0;
    integer tests_failed = 0;

    fp32_add  dut_add  (.clk(clk), .rst(rst), .valid_in(add_v_in),  .a(a), .b(b), .valid_out(add_v_out),  .y(y_add));
    fp32_mul  dut_mul  (.clk(clk), .rst(rst), .valid_in(mul_v_in),  .a(a), .b(b), .valid_out(mul_v_out),  .y(y_mul));
    fp32_div  dut_div  (.clk(clk), .rst(rst), .valid_in(div_v_in),  .a(a), .b(b), .valid_out(div_v_out),  .y(y_div));
    fp32_sqrt dut_sqrt (.clk(clk), .rst(rst), .valid_in(sqrt_v_in), .a(a),        .valid_out(sqrt_v_out), .y(y_sqrt));
    fp32_cbrt dut_cbrt (.clk(clk), .rst(rst), .valid_in(cbrt_v_in), .a(a),        .valid_out(cbrt_v_out), .y(y_cbrt));
    fp32_acos dut_acos (.clk(clk), .rst(rst), .valid_in(acos_v_in), .a(a),        .valid_out(acos_v_out), .y(y_acos));
    fp32_cos  dut_cos  (.clk(clk), .rst(rst), .valid_in(cos_v_in),  .a(a),        .valid_out(cos_v_out),  .y(y_cos));
    
    always #5 clk = ~clk;

    function real fp32_to_real;
        input [31:0] fp;
        real mantissa;
        real exp_val;
        integer exp_int;
        begin
            if (fp[30:23] == 255) begin
                fp32_to_real = 9999999.0;
            end else if (fp[30:0] == 0) begin
                fp32_to_real = 0.0;
            end else begin
                mantissa = 1.0 + ($itor(fp[22:0]) / 8388608.0);
                exp_int = fp[30:23] - 127;
                exp_val = 2.0 ** exp_int;
                fp32_to_real = mantissa * exp_val;
                if (fp[31]) fp32_to_real = -fp32_to_real;
            end
        end
    endfunction

    function real abs_real;
        input real val;
        begin
            abs_real = (val < 0.0) ? -val : val;
        end
    endfunction

    task check_result;
        input [80*8-1:0] op_name;
        input [31:0] actual_bits;
        input real   expected_val;
        input real   tolerance;
        real actual_val;
        real error_margin;
        begin
            actual_val = fp32_to_real(actual_bits);
            error_margin = abs_real(expected_val - actual_val);
            
            if (error_margin <= tolerance + (abs_real(expected_val) * tolerance)) begin
                $display("[PASS] %s | Expected: %f | Got: %f (Hex: %h)", op_name, expected_val, actual_val, actual_bits);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] %s | Expected: %f | Got: %f (Hex: %h) | Error: %f", op_name, expected_val, actual_val, actual_bits, error_margin);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task check_corner;
        input [80*8-1:0] op_name;
        input [31:0] actual_bits;
        input [31:0] expected_bits;
        begin
            if (actual_bits === expected_bits || (expected_bits == FP_NAN && actual_bits[30:23] == 8'hFF && actual_bits[22:0] != 0)) begin
                $display("[PASS] CORNER %s | Got Expected Bits: %h", op_name, actual_bits);
                tests_passed = tests_passed + 1;
            end else begin
                $display("[FAIL] CORNER %s | Expected Bits: %h | Got: %h", op_name, expected_bits, actual_bits);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    task run_add(input [31:0] va, input [31:0] vb); begin @(posedge clk); a=va; b=vb; add_v_in=1; @(posedge clk); add_v_in=0; wait(add_v_out); @(posedge clk); end endtask
    task run_mul(input [31:0] va, input [31:0] vb); begin @(posedge clk); a=va; b=vb; mul_v_in=1; @(posedge clk); mul_v_in=0; wait(mul_v_out); @(posedge clk); end endtask
    task run_div(input [31:0] va, input [31:0] vb); begin @(posedge clk); a=va; b=vb; div_v_in=1; @(posedge clk); div_v_in=0; wait(div_v_out); @(posedge clk); end endtask
    task run_sqrt(input [31:0] va);                 begin @(posedge clk); a=va;       sqrt_v_in=1; @(posedge clk); sqrt_v_in=0; wait(sqrt_v_out); @(posedge clk); end endtask
    task run_cbrt(input [31:0] va);                 begin @(posedge clk); a=va;       cbrt_v_in=1; @(posedge clk); cbrt_v_in=0; wait(cbrt_v_out); @(posedge clk); end endtask
    task run_acos(input [31:0] va);                 begin @(posedge clk); a=va;       acos_v_in=1; @(posedge clk); acos_v_in=0; wait(acos_v_out); @(posedge clk); end endtask
    task run_cos(input [31:0] va);                  begin @(posedge clk); a=va;       cos_v_in=1;  @(posedge clk); cos_v_in=0;  wait(cos_v_out);  @(posedge clk); end endtask

    initial begin
        clk = 0; rst = 1; a = 0; b = 0;
        add_v_in = 0; mul_v_in = 0; div_v_in = 0; sqrt_v_in = 0; cbrt_v_in = 0; acos_v_in = 0; cos_v_in = 0;
        
        #20;
        rst = 0;
        #20;

        $display("\n--- Testing ADDITION ---");
        run_add(FP_1, FP_2);            check_result("1.0 + 2.0", y_add, 3.0, 0.001);
        run_add(FP_2, FP_NEG_1);        check_result("2.0 + (-1.0)", y_add, 1.0, 0.001);
        run_add(FP_100, FP_0_5);        check_result("100.0 + 0.5", y_add, 100.5, 0.001);
        run_add(FP_NEG_2, FP_NEG_4);    check_result("-2.0 + (-4.0)", y_add, -6.0, 0.001);
        run_add(FP_100, 32'hC2C70000);  check_result("100.0 - 99.5", y_add, 0.5, 0.01); 

        run_add(FP_1, FP_NEG_1);        check_corner("1.0 + (-1.0) = 0.0", y_add, FP_0);
        run_add(FP_100, FP_NEG_100);    check_corner("100.0 + (-100.0) = 0.0", y_add, FP_0);
        run_add(FP_1, FP_0);            check_corner("1.0 + 0.0 = 1.0", y_add, FP_1);
        run_add(FP_NEG_0, FP_NEG_0);    check_corner("-0.0 + -0.0 = -0.0", y_add, FP_NEG_0);

        $display("\n--- Testing MULTIPLICATION ---");
        run_mul(FP_2, FP_3);            check_result("2.0 * 3.0", y_mul, 6.0, 0.001);
        run_mul(FP_NEG_2, FP_3);        check_result("-2.0 * 3.0", y_mul, -6.0, 0.001);
        run_mul(FP_0_5, FP_0_5);        check_result("0.5 * 0.5", y_mul, 0.25, 0.001);
        run_mul(FP_NEG_2, FP_NEG_4);    check_result("-2.0 * -4.0", y_mul, 8.0, 0.001);
        run_mul(FP_100, FP_1);          check_result("100.0 * 1.0", y_mul, 100.0, 0.001);

        run_mul(FP_100, FP_0);          check_corner("100.0 * 0.0 = 0.0", y_mul, FP_0);
        run_mul(FP_NEG_1, FP_0);        check_corner("-1.0 * 0.0 = -0.0", y_mul, FP_NEG_0);
        run_mul(FP_0, FP_NEG_100);      check_corner("0.0 * -100.0 = -0.0", y_mul, FP_NEG_0);

        $display("\n--- Testing DIVISION ---");
        run_div(FP_3, FP_2);            check_result("3.0 / 2.0", y_div, 1.5, 0.001);
        run_div(FP_1, FP_NEG_2);        check_result("1.0 / -2.0", y_div, -0.5, 0.001);
        run_div(FP_1, FP_3);            check_result("1.0 / 3.0", y_div, 0.333333, 0.001);
        run_div(FP_NEG_4, FP_NEG_2);    check_result("-4.0 / -2.0", y_div, 2.0, 0.001);
        run_div(FP_100, FP_1);          check_result("100.0 / 1.0", y_div, 100.0, 0.001);
        
        run_div(FP_0, FP_100);          check_corner("0.0 / 100.0 = 0.0", y_div, FP_0);
        run_div(FP_0, FP_NEG_100);      check_corner("0.0 / -100.0 = -0.0", y_div, FP_NEG_0);
        run_div(FP_1, FP_0);            check_corner("1.0 / 0.0 = +Inf", y_div, FP_INF);
        run_div(FP_NEG_1, FP_0);        check_corner("-1.0 / 0.0 = -Inf", y_div, FP_NEG_INF);

        $display("\n--- Testing SQUARE ROOT ---");
        run_sqrt(FP_4);                 check_result("sqrt(4.0)", y_sqrt, 2.0, 0.05);
        run_sqrt(FP_2);                 check_result("sqrt(2.0)", y_sqrt, 1.4142, 0.05);
        run_sqrt(FP_0_25);              check_result("sqrt(0.25)", y_sqrt, 0.5, 0.05);
        run_sqrt(FP_1);                 check_result("sqrt(1.0)", y_sqrt, 1.0, 0.05);
        run_sqrt(FP_100);               check_result("sqrt(100.0)", y_sqrt, 10.0, 0.05);
        run_sqrt(FP_0_01);              check_result("sqrt(0.01)", y_sqrt, 0.1, 0.10);

        run_sqrt(FP_0);                 check_corner("sqrt(0.0) = 0.0", y_sqrt, FP_0);
        run_sqrt(FP_NEG_4);             check_corner("sqrt(-4.0) = NaN", y_sqrt, FP_NAN);

        $display("\n--- Testing CUBE ROOT ---");
        run_cbrt(FP_8);                 check_result("cbrt(8.0)", y_cbrt, 2.0, 0.05);
        run_cbrt(FP_NEG_8);             check_result("cbrt(-8.0)", y_cbrt, -2.0, 0.05);
        run_cbrt(FP_1);                 check_result("cbrt(1.0)", y_cbrt, 1.0, 0.05);
        run_cbrt(FP_NEG_1);             check_result("cbrt(-1.0)", y_cbrt, -1.0, 0.05);
        run_cbrt(FP_27);                check_result("cbrt(27.0)", y_cbrt, 3.0, 0.05);
        run_cbrt(FP_NEG_27);            check_result("cbrt(-27.0)", y_cbrt, -3.0, 0.05);
        run_cbrt(FP_0_125);             check_result("cbrt(0.125)", y_cbrt, 0.5, 0.05);

        run_cbrt(FP_0);                 check_corner("cbrt(0.0) = 0.0", y_cbrt, FP_0);

        $display("\n--- Testing ARC COSINE ---");
        run_acos(FP_0);                 check_result("acos(0.0)", y_acos, 1.570796, 0.05);
        run_acos(FP_1);                 check_result("acos(1.0)", y_acos, 0.0, 0.05);
        run_acos(FP_0_5);               check_result("acos(0.5)", y_acos, 1.047197, 0.08);
        run_acos(FP_NEG_1);             check_result("acos(-1.0)", y_acos, 3.141592, 0.05);
        run_acos(FP_NEG_0_5);           check_result("acos(-0.5)", y_acos, 2.094395, 0.08);

        $display("\n--- Testing COSINE ---");
        run_cos(FP_0);                  check_result("cos(0.0)", y_cos, 1.0, 0.05);
        run_cos(FP_1);                  check_result("cos(1.0)", y_cos, 0.540302, 0.05);
        run_cos(FP_PI_HALF);            check_result("cos(PI/2)", y_cos, 0.0, 0.08);
        run_cos(FP_NEG_1);              check_result("cos(-1.0)", y_cos, 0.540302, 0.05);
        run_cos(FP_PI);                 check_result("cos(PI)", y_cos, -1.0, 0.08);
        run_cos(FP_NEG_PI_HALF);        check_result("cos(-PI/2)", y_cos, 0.0, 0.08);

        $display("\n=================================================");
        $display("                   TEST SUMMARY                  ");
        $display("=================================================");
        $display(" Passed: %0d", tests_passed);
        $display(" Failed: %0d", tests_failed);
        if (tests_failed == 0)
            $display(" RESULT: ALL TESTS PASSED SUCCESSFULLY");
        else
            $display(" RESULT: SOME TESTS FAILED. CHECK LOGS.");
        $display("=================================================\n");
        
        $finish;
    end

endmodule