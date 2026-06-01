`timescale 1ns/1ps

module tb_fp32_math();

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

    fp32_add  dut_add  (.a(a), .b(b), .y(y_add));
    fp32_mul  dut_mul  (.a(a), .b(b), .y(y_mul));
    fp32_div  dut_div  (.a(a), .b(b), .y(y_div));
    fp32_sqrt dut_sqrt (.a(a), .y(y_sqrt));
    fp32_cbrt dut_cbrt (.a(a), .y(y_cbrt));
    fp32_acos dut_acos (.a(a), .y(y_acos));
    fp32_cos  dut_cos  (.a(a), .y(y_cos));
    
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

    initial begin
        $display("\n--- Testing ADDITION ---");
        a = FP_1; b = FP_2; #10; check_result("1.0 + 2.0", y_add, 3.0, 0.001);
        a = FP_2; b = FP_NEG_1; #10; check_result("2.0 + (-1.0)", y_add, 1.0, 0.001);
        a = FP_100; b = FP_0_5; #10; check_result("100.0 + 0.5", y_add, 100.5, 0.001);
        
        a = FP_NEG_2; b = FP_NEG_4; #10; check_result("-2.0 + (-4.0)", y_add, -6.0, 0.001);
        a = FP_100; b = 32'hC2C70000; #10; check_result("100.0 - 99.5", y_add, 0.5, 0.01); 

        a = FP_1; b = FP_NEG_1; #10; check_corner("1.0 + (-1.0) = 0.0", y_add, FP_0);
        a = FP_100; b = FP_NEG_100; #10; check_corner("100.0 + (-100.0) = 0.0", y_add, FP_0);
        a = FP_1; b = FP_0; #10; check_corner("1.0 + 0.0 = 1.0", y_add, FP_1);
        a = FP_NEG_0; b = FP_NEG_0; #10; check_corner("-0.0 + -0.0 = -0.0", y_add, FP_NEG_0);

        $display("\n--- Testing MULTIPLICATION ---");
        a = FP_2; b = FP_3; #10; check_result("2.0 * 3.0", y_mul, 6.0, 0.001);
        a = FP_NEG_2; b = FP_3; #10; check_result("-2.0 * 3.0", y_mul, -6.0, 0.001);
        a = FP_0_5; b = FP_0_5; #10; check_result("0.5 * 0.5", y_mul, 0.25, 0.001);
        
        a = FP_NEG_2; b = FP_NEG_4; #10; check_result("-2.0 * -4.0", y_mul, 8.0, 0.001);
        a = FP_100; b = FP_1; #10; check_result("100.0 * 1.0", y_mul, 100.0, 0.001);

        a = FP_100; b = FP_0; #10; check_corner("100.0 * 0.0 = 0.0", y_mul, FP_0);
        a = FP_NEG_1; b = FP_0; #10; check_corner("-1.0 * 0.0 = -0.0", y_mul, FP_NEG_0);
        a = FP_0; b = FP_NEG_100; #10; check_corner("0.0 * -100.0 = -0.0", y_mul, FP_NEG_0);

        $display("\n--- Testing DIVISION ---");
        a = FP_3; b = FP_2; #10; check_result("3.0 / 2.0", y_div, 1.5, 0.001);
        a = FP_1; b = FP_NEG_2; #10; check_result("1.0 / -2.0", y_div, -0.5, 0.001);
        a = FP_1; b = FP_3; #10; check_result("1.0 / 3.0", y_div, 0.333333, 0.001);

        a = FP_NEG_4; b = FP_NEG_2; #10; check_result("-4.0 / -2.0", y_div, 2.0, 0.001);
        a = FP_100; b = FP_1; #10; check_result("100.0 / 1.0", y_div, 100.0, 0.001);
        
        a = FP_0; b = FP_100; #10; check_corner("0.0 / 100.0 = 0.0", y_div, FP_0);
        a = FP_0; b = FP_NEG_100; #10; check_corner("0.0 / -100.0 = -0.0", y_div, FP_NEG_0);
        a = FP_1; b = FP_0; #10; check_corner("1.0 / 0.0 = +Inf", y_div, FP_INF);
        a = FP_NEG_1; b = FP_0; #10; check_corner("-1.0 / 0.0 = -Inf", y_div, FP_NEG_INF);

        $display("\n--- Testing SQUARE ROOT ---");
        a = FP_4; #10; check_result("sqrt(4.0)", y_sqrt, 2.0, 0.05);
        a = FP_2; #10; check_result("sqrt(2.0)", y_sqrt, 1.4142, 0.05);
        a = FP_0_25; #10; check_result("sqrt(0.25)", y_sqrt, 0.5, 0.05);
        
        a = FP_1; #10; check_result("sqrt(1.0)", y_sqrt, 1.0, 0.05);
        a = FP_100; #10; check_result("sqrt(100.0)", y_sqrt, 10.0, 0.05);
        a = FP_0_01; #10; check_result("sqrt(0.01)", y_sqrt, 0.1, 0.10);

        a = FP_0; #10; check_corner("sqrt(0.0) = 0.0", y_sqrt, FP_0);
        a = FP_NEG_4; #10; check_corner("sqrt(-4.0) = NaN", y_sqrt, FP_NAN);

        $display("\n--- Testing CUBE ROOT ---");
        a = FP_8; #10; check_result("cbrt(8.0)", y_cbrt, 2.0, 0.05);
        a = FP_NEG_8; #10; check_result("cbrt(-8.0)", y_cbrt, -2.0, 0.05);
        a = FP_1; #10; check_result("cbrt(1.0)", y_cbrt, 1.0, 0.05);
        
        a = FP_NEG_1; #10; check_result("cbrt(-1.0)", y_cbrt, -1.0, 0.05);
        a = FP_27; #10; check_result("cbrt(27.0)", y_cbrt, 3.0, 0.05);
        a = FP_NEG_27; #10; check_result("cbrt(-27.0)", y_cbrt, -3.0, 0.05);
        a = FP_0_125; #10; check_result("cbrt(0.125)", y_cbrt, 0.5, 0.05);

        a = FP_0; #10; check_corner("cbrt(0.0) = 0.0", y_cbrt, FP_0);

        $display("\n--- Testing ARC COSINE ---");
        a = FP_0; #10; check_result("acos(0.0)", y_acos, 1.570796, 0.05);
        a = FP_1; #10; check_result("acos(1.0)", y_acos, 0.0, 0.05);
        a = FP_0_5; #10; check_result("acos(0.5)", y_acos, 1.047197, 0.08);

        a = FP_NEG_1; #10; check_result("acos(-1.0)", y_acos, 3.141592, 0.05);
        a = FP_NEG_0_5; #10; check_result("acos(-0.5)", y_acos, 2.094395, 0.08);

        $display("\n--- Testing COSINE ---");
        a = FP_0; #10; check_result("cos(0.0)", y_cos, 1.0, 0.05);
        a = FP_1; #10; check_result("cos(1.0)", y_cos, 0.540302, 0.05);
        a = FP_PI_HALF; #10; check_result("cos(PI/2)", y_cos, 0.0, 0.08);

        a = FP_NEG_1; #10; check_result("cos(-1.0)", y_cos, 0.540302, 0.05);
        a = FP_PI; #10; check_result("cos(PI)", y_cos, -1.0, 0.08);
        a = FP_NEG_PI_HALF; #10; check_result("cos(-PI/2)", y_cos, 0.0, 0.08);

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