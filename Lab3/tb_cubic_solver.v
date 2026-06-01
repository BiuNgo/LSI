`timescale 1ns/1ps

module tb_cubic_solver();

    reg         clk;
    reg         rst_n;
    reg         start;
    reg  [31:0] a, b, c, d;
    
    wire [31:0] x0_re, x0_im;
    wire [31:0] x1_re, x1_im;
    wire [31:0] x2_re, x2_im;
    wire        valid;
    wire        error;

    localparam [31:0] FP_0    = 32'h00000000;
    localparam [31:0] FP_1    = 32'h3F800000; // 1.0
    localparam [31:0] FP_M1   = 32'hBF800000; // -1.0
    localparam [31:0] FP_2    = 32'h40000000; // 2.0
    localparam [31:0] FP_M2   = 32'hC0000000; // -2.0
    localparam [31:0] FP_3    = 32'h40400000; // 3.0
    localparam [31:0] FP_M4   = 32'hC0800000; // -4.0
    localparam [31:0] FP_5    = 32'h40A00000; // 5.0
    localparam [31:0] FP_M6   = 32'hC0C00000; // -6.0
    localparam [31:0] FP_M8   = 32'hC1000000; // -8.0
    localparam [31:0] FP_11   = 32'h41300000; // 11.0
    localparam [31:0] FP_12   = 32'h41400000; // 12.0

    cubic_solver dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a(a), .b(b), .c(c), .d(d),
        .x0_re(x0_re), .x0_im(x0_im),
        .x1_re(x1_re), .x1_im(x1_im),
        .x2_re(x2_re), .x2_im(x2_im),
        .valid(valid),
        .error(error)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function real fp32_to_real;
        input [31:0] fp;
        real mantissa;
        real exp_val;
        integer exp_int;
        begin
            if (fp[30:23] == 255) begin
                fp32_to_real = 9999999.0; // Proxy for NaN
            end else if (fp[30:0] == 0) begin
                fp32_to_real = 0.0;
            end else begin
                mantissa = 1.0 + ($itor(fp[22:0]) / 8388608.0); // 2^23
                exp_int = fp[30:23] - 127;
                exp_val = 2.0 ** exp_int;
                fp32_to_real = mantissa * exp_val;
                if (fp[31]) fp32_to_real = -fp32_to_real;
            end
        end
    endfunction

    task run_test;
        input [80*8-1:0] test_name;
        input [31:0] in_a, in_b, in_c, in_d;
        begin
            $display("---------------------------------------------------------");
            $display("RUNNING: %s", test_name);
            
            // Set inputs
            a = in_a; b = in_b; c = in_c; d = in_d;
            
            // Pulse start
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;
            
            // Wait for FSM to assert valid
            wait(valid == 1'b1);
            @(posedge clk);

            // Print Results
            if (error) begin
                $display(">>> ERROR FLAG ASSERTED (Invalid Equation) <<<");
            end else begin
                $display("Root 0:  %f + %fi", fp32_to_real(x0_re), fp32_to_real(x0_im));
                $display("Root 1:  %f + %fi", fp32_to_real(x1_re), fp32_to_real(x1_im));
                $display("Root 2:  %f + %fi", fp32_to_real(x2_re), fp32_to_real(x2_im));
            end
            $display("---------------------------------------------------------\n");
            
            // Allow a few cycles before next test
            #50;
        end
    endtask

    initial begin
        // Reset sequence
        rst_n = 0;
        start = 0;
        a = 0; b = 0; c = 0; d = 0;
        #20 rst_n = 1;
        #10;
        
        $display("\n=========================================================");
        $display("             CUBIC SOLVER MODULE TESTBENCH               ");
        $display("=========================================================\n");

        // TEST 1: Three Distinct Real Roots (Trigonometric Method)
        // Equation: (x-1)(x-2)(x-3) = x^3 - 6x^2 + 11x - 6 = 0
        // Expected Roots: 1, 2, 3 (Imaginary parts = 0)
        run_test("3 Distinct Real Roots | Eq: x^3 - 6x^2 + 11x - 6 = 0", 
                 FP_1, FP_M6, FP_11, FP_M6);

        // TEST 2: One Real, Two Complex Roots (Cardano's Method)
        // Equation: (x-1)(x^2+1) = x^3 - x^2 + x - 1 = 0
        // Expected Roots: 1,  0 + 1i,  0 - 1i
        run_test("1 Real, 2 Complex Roots | Eq: x^3 - x^2 + x - 1 = 0", 
                 FP_1, FP_M1, FP_1, FP_M1);

        // TEST 3: Double Root (Cardano's Method D=0)
        // Equation: (x-1)(x-1)(x-2) = x^3 - 4x^2 + 5x - 2 = 0
        // Expected Roots: 1, 1, 2
        run_test("Double Root | Eq: x^3 - 4x^2 + 5x - 2 = 0", 
                 FP_1, FP_M4, FP_5, FP_M2);

        // TEST 4: Triple Root (Cardano's Method D=0, P=0)
        // Equation: (x-2)^3 = x^3 - 6x^2 + 12x - 8 = 0
        // Expected Roots: 2, 2, 2
        run_test("Triple Root | Eq: x^3 - 6x^2 + 12x - 8 = 0", 
                 FP_1, FP_M6, FP_12, FP_M8);

        // TEST 5: Edge Case - Invalid Cubic Equation (a = 0)
        // Equation: 0x^3 + 2x^2 + 3x - 1 = 0
        // Expected: error flag = 1, outputs = NaN
        run_test("Invalid Cubic (a=0) | Eq: 0x^3 + 2x^2 + ... = 0", 
                 FP_0, FP_2, FP_3, FP_M1);

        $display("=========================================================");
        $display("                    TESTS COMPLETE                       ");
        $display("=========================================================\n");
        $finish;
    end

endmodule