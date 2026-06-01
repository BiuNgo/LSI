`timescale 1ns/1ps

module cubic_solver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire [31:0] d,
    
    // Complex format (Real + Imaginary)
    output reg  [31:0] x0_re,
    output reg  [31:0] x0_im,
    output reg  [31:0] x1_re,
    output reg  [31:0] x1_im,
    output reg  [31:0] x2_re,
    output reg  [31:0] x2_im,
    
    output reg         valid,
    output reg         error
);

    // IEEE 754 Constants
    localparam [31:0] FP_0_0      = 32'h00000000;
    localparam [31:0] FP_2_0      = 32'h40000000;
    localparam [31:0] FP_3_0      = 32'h40400000;
    localparam [31:0] FP_9_0      = 32'h41100000;
    localparam [31:0] FP_27_0     = 32'h41D80000;
    
    localparam [31:0] FP_M1_0     = 32'hBF800000; // -1.0
    localparam [31:0] FP_M0_5     = 32'hBF000000; // -0.5
    localparam [31:0] FP_0_25     = 32'h3E800000; // 0.25
    localparam [31:0] FP_1_3      = 32'h3EAAAAAB; // 1/3
    localparam [31:0] FP_M1_3     = 32'hBEAAAAAB; // -1/3
    localparam [31:0] FP_1_27     = 32'h3D17B42C; // 1/27
    
    localparam [31:0] FP_SQRT3_2  = 32'h3F5DB3E2; // sqrt(3)/2
    localparam [31:0] FP_2PI_3    = 32'h40060A92; // 2pi/3
    localparam [31:0] FP_NAN      = 32'h7FC00000;

    // Shared ALU IO
    reg  [31:0] add1_a, add1_b, add2_a, add2_b, add3_a, add3_b;
    wire [31:0] add1_o, add2_o, add3_o;
    reg  [31:0] mul1_a, mul1_b, mul2_a, mul2_b, mul3_a, mul3_b, mul4_a, mul4_b;
    wire [31:0] mul1_o, mul2_o, mul3_o, mul4_o;
    reg  [31:0] div1_a, div1_b;
    wire [31:0] div1_o;
    reg  [31:0] sqrt1_a, sqrt2_a, cbrt1_a, cbrt2_a, acos1_a, cos1_a, cos2_a, cos3_a;
    wire [31:0] sqrt1_o, sqrt2_o, cbrt1_o, cbrt2_o, acos1_o, cos1_o, cos2_o, cos3_o;

    // =========================================================================
    // FSM States (Verilog-2001 Compliant)
    // =========================================================================
    reg [4:0] state;
    localparam [4:0] 
        IDLE  = 5'd0,  S_P1  = 5'd1,  S_P2  = 5'd2,  S_P3  = 5'd3,
        S_P4  = 5'd4,  S_P5  = 5'd5,  S_P6  = 5'd6,  S_P7  = 5'd7,
        S_P8  = 5'd8,  S_P9  = 5'd9,  S_P10 = 5'd10,
        S_C1  = 5'd11, S_C2  = 5'd12, S_C3  = 5'd13, S_C4  = 5'd14,
        S_C5  = 5'd15, S_C6  = 5'd16, S_C7  = 5'd17,
        S_T1  = 5'd18, S_T2  = 5'd19, S_T3  = 5'd20, S_T4  = 5'd21,
        S_T5  = 5'd22, S_T6  = 5'd23, S_T7  = 5'd24, S_T8  = 5'd25,
        S_T9  = 5'd26, S_T10 = 5'd27;

    // Pipeline Registers
    reg [31:0] a2, b2, ac, ad, a_3, a3, ac3, b3, a2d, b_3a, b3_2, ac9, a2d27, a2_3, p_num;
    reg [31:0] abc9, a3_27, p, q_part1, q_num, p2, q, p3, q2, p3_27, q2_4, D;
    reg [31:0] D_sqrt, q_half_neg, u_arg, v_arg, u, v, u_plus_v, u_minus_v, t12_re, t1_im, x12_re;
    reg [31:0] r_ins, p_m_1_3, r, sqrt_p_m_1_3, acos_arg, r_mul, theta, theta_3;
    reg [31:0] theta_3_m, theta_3_p, cos0, cos1, cos2, t0, t1, t2;
    reg [31:0] x0_re_t, x1_re_t, x2_re_t;

    // Discriminant Check (Sign bit 0 = positive, unless perfectly 0)
    wire D_is_neg = D[31] && (D[30:0] != 31'd0); 

    // ALU Muxing based on current state
    always @(*) begin
        // Prevent latches
        add1_a = 0; add1_b = 0; add2_a = 0; add2_b = 0; add3_a = 0; add3_b = 0;
        mul1_a = 0; mul1_b = 0; mul2_a = 0; mul2_b = 0; mul3_a = 0; mul3_b = 0; mul4_a = 0; mul4_b = 0;
        div1_a = 0; div1_b = FP_1_3; // non-zero default
        sqrt1_a = 0; sqrt2_a = 0; cbrt1_a = 0; cbrt2_a = 0;
        acos1_a = 0; cos1_a = 0; cos2_a = 0; cos3_a = 0;
        
        case (state)
            S_P1: begin
                mul1_a = a; mul1_b = a; mul2_a = b; mul2_b = b;
                mul3_a = a; mul3_b = c; mul4_a = FP_3_0; mul4_b = a;
            end
            S_P2: begin
                mul1_a = a2; mul1_b = a; mul2_a = FP_3_0; mul2_b = ac;
                mul3_a = b2; mul3_b = b; mul4_a = a2; mul4_b = d;
                div1_a = b; div1_b = a_3;
            end
            S_P3: begin
                mul1_a = FP_2_0; mul1_b = b3; mul2_a = FP_9_0; mul2_b = ac;
                mul3_a = FP_27_0; mul3_b = a2d; mul4_a = FP_3_0; mul4_b = a2;
                add1_a = ac3; add1_b = {~b2[31], b2[30:0]}; // ac3 - b2
            end
            S_P4: begin
                mul1_a = ac9; mul1_b = b; mul2_a = FP_27_0; mul2_b = a3;
                div1_a = p_num; div1_b = a2_3;
                add1_a = b3_2; add1_b = a2d27;
            end
            S_P5: begin
                add1_a = q_part1; add1_b = {~abc9[31], abc9[30:0]}; // - abc9
                mul1_a = p; mul1_b = p;
            end
            S_P6: begin div1_a = q_num; div1_b = a3_27; mul1_a = p2; mul1_b = p; end
            S_P7: begin mul1_a = q; mul1_b = q; mul2_a = p3; mul2_b = FP_1_27; end
            S_P8: begin mul1_a = q2; mul1_b = FP_0_25; end
            S_P9: begin add1_a = q2_4; add1_b = p3_27; end
            
            // CARDANO DATAPATH (D >= 0)
            S_C1: begin sqrt1_a = D; mul1_a = q; mul1_b = FP_M0_5; end
            S_C2: begin 
                add1_a = q_half_neg; add1_b = D_sqrt; 
                add2_a = q_half_neg; add2_b = {~D_sqrt[31], D_sqrt[30:0]};
            end
            S_C3: begin cbrt1_a = u_arg; cbrt2_a = v_arg; end
            S_C4: begin add1_a = u; add1_b = v; add2_a = u; add2_b = {~v[31], v[30:0]}; end
            S_C5: begin 
                mul1_a = u_plus_v; mul1_b = FP_M0_5;
                mul2_a = u_minus_v; mul2_b = FP_SQRT3_2;
                add1_a = u_plus_v; add1_b = {~b_3a[31], b_3a[30:0]};
            end
            S_C6: begin add1_a = t12_re; add1_b = {~b_3a[31], b_3a[30:0]}; end

            // TRIGONOMETRIC DATAPATH (D < 0)
            S_T1: begin
                mul1_a = p3_27; mul1_b = FP_M1_0;
                mul2_a = q; mul2_b = FP_M0_5;
                mul3_a = p; mul3_b = FP_M1_3;
            end
            S_T2: begin sqrt1_a = r_ins; sqrt2_a = p_m_1_3; end
            S_T3: begin div1_a = q_half_neg; div1_b = r; mul1_a = sqrt_p_m_1_3; mul1_b = FP_2_0; end
            S_T4: begin acos1_a = acos_arg; end
            S_T5: begin mul1_a = theta; mul1_b = FP_1_3; end
            S_T6: begin 
                add1_a = theta_3; add1_b = {~FP_2PI_3[31], FP_2PI_3[30:0]}; 
                add2_a = theta_3; add2_b = FP_2PI_3; 
            end
            S_T7: begin cos1_a = theta_3; cos2_a = theta_3_m; cos3_a = theta_3_p; end
            S_T8: begin mul1_a = r_mul; mul1_b = cos0; mul2_a = r_mul; mul2_b = cos1; mul3_a = r_mul; mul3_b = cos2; end
            S_T9: begin
                add1_a = t0; add1_b = {~b_3a[31], b_3a[30:0]};
                add2_a = t1; add2_b = {~b_3a[31], b_3a[30:0]};
                add3_a = t2; add3_b = {~b_3a[31], b_3a[30:0]};
            end
        endcase
    end

    // =========================================================================
    // Wait-Free Sequential FSM Process (1 State per Clock Cycle)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0; error <= 0;
            x0_re <= FP_NAN; x0_im <= FP_NAN; x1_re <= FP_NAN; 
            x1_im <= FP_NAN; x2_re <= FP_NAN; x2_im <= FP_NAN;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        valid <= 0;
                        if (a[30:0] == 31'd0) begin // Edge Case: Not a cubic equation.
                            error <= 1; valid <= 1;
                            x0_re <= FP_NAN; x0_im <= FP_NAN;
                            x1_re <= FP_NAN; x1_im <= FP_NAN;
                            x2_re <= FP_NAN; x2_im <= FP_NAN;
                        end else begin
                            error <= 0; state <= S_P1;
                        end
                    end
                end
                
                // Preparation States
                S_P1: begin a2 <= mul1_o; b2 <= mul2_o; ac <= mul3_o; a_3 <= mul4_o; state <= S_P2; end
                S_P2: begin a3 <= mul1_o; ac3 <= mul2_o; b3 <= mul3_o; a2d <= mul4_o; b_3a <= div1_o; state <= S_P3; end
                S_P3: begin b3_2 <= mul1_o; ac9 <= mul2_o; a2d27 <= mul3_o; a2_3 <= mul4_o; p_num <= add1_o; state <= S_P4; end
                S_P4: begin abc9 <= mul1_o; a3_27 <= mul2_o; p <= div1_o; q_part1 <= add1_o; state <= S_P5; end
                S_P5: begin q_num <= add1_o; p2 <= mul1_o; state <= S_P6; end
                S_P6: begin q <= div1_o; p3 <= mul1_o; state <= S_P7; end
                S_P7: begin q2 <= mul1_o; p3_27 <= mul2_o; state <= S_P8; end
                S_P8: begin q2_4 <= mul1_o; state <= S_P9; end
                S_P9: begin D <= add1_o; state <= S_P10; end
                S_P10: begin
                    if (D_is_neg) state <= S_T1; else state <= S_C1;
                end
                
                // Cardano Path
                S_C1: begin D_sqrt <= sqrt1_o; q_half_neg <= mul1_o; state <= S_C2; end
                S_C2: begin u_arg <= add1_o; v_arg <= add2_o; state <= S_C3; end
                S_C3: begin u <= cbrt1_o; v <= cbrt2_o; state <= S_C4; end
                S_C4: begin u_plus_v <= add1_o; u_minus_v <= add2_o; state <= S_C5; end
                S_C5: begin t12_re <= mul1_o; t1_im <= mul2_o; x0_re <= add1_o; state <= S_C6; end
                S_C6: begin x12_re <= add1_o; state <= S_C7; end
                S_C7: begin
                    x0_im <= FP_0_0;
                    x1_re <= x12_re; x1_im <= t1_im;
                    x2_re <= x12_re; x2_im <= (t1_im[30:0] == 0) ? FP_0_0 : {~t1_im[31], t1_im[30:0]};
                    valid <= 1; state <= IDLE;
                end
                
                // Trig Path
                S_T1: begin r_ins <= mul1_o; q_half_neg <= mul2_o; p_m_1_3 <= mul3_o; state <= S_T2; end
                S_T2: begin r <= sqrt1_o; sqrt_p_m_1_3 <= sqrt2_o; state <= S_T3; end
                S_T3: begin acos_arg <= div1_o; r_mul <= mul1_o; state <= S_T4; end
                S_T4: begin theta <= acos1_o; state <= S_T5; end
                S_T5: begin theta_3 <= mul1_o; state <= S_T6; end
                S_T6: begin theta_3_m <= add1_o; theta_3_p <= add2_o; state <= S_T7; end
                S_T7: begin cos0 <= cos1_o; cos1 <= cos2_o; cos2 <= cos3_o; state <= S_T8; end
                S_T8: begin t0 <= mul1_o; t1 <= mul2_o; t2 <= mul3_o; state <= S_T9; end
                S_T9: begin x0_re_t <= add1_o; x1_re_t <= add2_o; x2_re_t <= add3_o; state <= S_T10; end
                S_T10: begin
                    x0_re <= x0_re_t; x0_im <= FP_0_0;
                    x1_re <= x1_re_t; x1_im <= FP_0_0;
                    x2_re <= x2_re_t; x2_im <= FP_0_0;
                    valid <= 1; state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // =========================================================================
    // IP Module Instantiations
    // =========================================================================
    fp32_add adder1 (.a(add1_a), .b(add1_b), .y(add1_o));
    fp32_add adder2 (.a(add2_a), .b(add2_b), .y(add2_o));
    fp32_add adder3 (.a(add3_a), .b(add3_b), .y(add3_o));
    
    fp32_mul mult1  (.a(mul1_a), .b(mul1_b), .y(mul1_o));
    fp32_mul mult2  (.a(mul2_a), .b(mul2_b), .y(mul2_o));
    fp32_mul mult3  (.a(mul3_a), .b(mul3_b), .y(mul3_o));
    fp32_mul mult4  (.a(mul4_a), .b(mul4_b), .y(mul4_o));

    fp32_div divider1 (.a(div1_a), .b(div1_b), .y(div1_o));

    fp32_sqrt square_root1 (.a(sqrt1_a), .y(sqrt1_o));
    fp32_sqrt square_root2 (.a(sqrt2_a), .y(sqrt2_o));
    
    fp32_cbrt cube_root1 (.a(cbrt1_a), .y(cbrt1_o));
    fp32_cbrt cube_root2 (.a(cbrt2_a), .y(cbrt2_o));
    
    fp32_acos arc_cos (.a(acos1_a), .y(acos1_o));
    
    fp32_cos cosine1 (.a(cos1_a), .y(cos1_o));
    fp32_cos cosine2 (.a(cos2_a), .y(cos2_o));
    fp32_cos cosine3 (.a(cos3_a), .y(cos3_o));

endmodule