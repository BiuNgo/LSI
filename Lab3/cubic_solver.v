`timescale 1ns/1ps

module cubic_solver (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,
    input  wire [31:0] d,
    
    output reg  [31:0] x0_re, x0_im,
    output reg  [31:0] x1_re, x1_im,
    output reg  [31:0] x2_re, x2_im,
    
    output reg         valid, 
    output reg         error
);

    localparam [31:0] FP_0_0      = 32'h00000000;
    localparam [31:0] FP_2_0      = 32'h40000000;
    localparam [31:0] FP_3_0      = 32'h40400000;
    localparam [31:0] FP_9_0      = 32'h41100000;
    localparam [31:0] FP_27_0     = 32'h41D80000;
    localparam [31:0] FP_M1_0     = 32'hBF800000;
    localparam [31:0] FP_M0_5     = 32'hBF000000;
    localparam [31:0] FP_0_25     = 32'h3E800000;
    localparam [31:0] FP_1_3      = 32'h3EAAAAAB;
    localparam [31:0] FP_M1_3     = 32'hBEAAAAAB;
    localparam [31:0] FP_1_27     = 32'h3D17B42C;
    localparam [31:0] FP_SQRT3_2  = 32'h3F5DB3E2;
    localparam [31:0] FP_2PI_3    = 32'h40060A92;
    localparam [31:0] FP_NAN      = 32'h7FC00000;

    reg add1_in_v, add2_in_v, add3_in_v;
    reg mul1_in_v, mul2_in_v, mul3_in_v, mul4_in_v;
    reg div1_in_v, sqrt_in_v, cbrt_in_v, acos_in_v, cos_in_v;

    wire add1_out_v, add2_out_v, add3_out_v;
    wire mul1_out_v, mul2_out_v, mul3_out_v, mul4_out_v;
    wire div1_out_v, sqrt_out_v, cbrt_out_v, acos_out_v, cos_out_v;

    reg [31:0] add1_a, add1_b, add2_a, add2_b, add3_a, add3_b;
    reg [31:0] mul1_a, mul1_b, mul2_a, mul2_b, mul3_a, mul3_b, mul4_a, mul4_b;
    reg [31:0] div1_a, div1_b, sqrt_a, cbrt_a, acos_a, cos_a;

    wire [31:0] add1_o, add2_o, add3_o;
    wire [31:0] mul1_o, mul2_o, mul3_o, mul4_o;
    wire [31:0] div1_o, sqrt_o, cbrt_o, acos_o, cos_o;

    reg [31:0] add1_reg, add2_reg, add3_reg;
    reg [31:0] mul1_reg, mul2_reg, mul3_reg, mul4_reg;
    reg [31:0] div1_reg, sqrt_reg, cbrt_reg, acos_reg, cos_reg;

    reg w_add1, w_add2, w_add3;
    reg w_mul1, w_mul2, w_mul3, w_mul4;
    reg w_div1, w_sqrt, w_cbrt, w_acos, w_cos;

    wire all_done = !(w_add1 | w_add2 | w_add3 | 
                      w_mul1 | w_mul2 | w_mul3 | w_mul4 | 
                      w_div1 | w_sqrt | w_cbrt | w_acos | w_cos);

    wire rst = ~rst_n;

    fp32_add add1 (.clk(clk), .rst(rst), .valid_in(add1_in_v), .a(add1_a), .b(add1_b), .valid_out(add1_out_v), .y(add1_o));
    fp32_add add2 (.clk(clk), .rst(rst), .valid_in(add2_in_v), .a(add2_a), .b(add2_b), .valid_out(add2_out_v), .y(add2_o));
    fp32_add add3 (.clk(clk), .rst(rst), .valid_in(add3_in_v), .a(add3_a), .b(add3_b), .valid_out(add3_out_v), .y(add3_o));

    fp32_mul mul1 (.clk(clk), .rst(rst), .valid_in(mul1_in_v), .a(mul1_a), .b(mul1_b), .valid_out(mul1_out_v), .y(mul1_o));
    fp32_mul mul2 (.clk(clk), .rst(rst), .valid_in(mul2_in_v), .a(mul2_a), .b(mul2_b), .valid_out(mul2_out_v), .y(mul2_o));
    fp32_mul mul3 (.clk(clk), .rst(rst), .valid_in(mul3_in_v), .a(mul3_a), .b(mul3_b), .valid_out(mul3_out_v), .y(mul3_o));
    fp32_mul mul4 (.clk(clk), .rst(rst), .valid_in(mul4_in_v), .a(mul4_a), .b(mul4_b), .valid_out(mul4_out_v), .y(mul4_o));

    fp32_div  div1 (.clk(clk), .rst(rst), .valid_in(div1_in_v), .a(div1_a), .b(div1_b), .valid_out(div1_out_v), .y(div1_o));
    fp32_sqrt sqr1 (.clk(clk), .rst(rst), .valid_in(sqrt_in_v), .a(sqrt_a),              .valid_out(sqrt_out_v), .y(sqrt_o));
    fp32_cbrt cbr1 (.clk(clk), .rst(rst), .valid_in(cbrt_in_v), .a(cbrt_a),              .valid_out(cbrt_out_v), .y(cbrt_o));
    fp32_acos aco1 (.clk(clk), .rst(rst), .valid_in(acos_in_v), .a(acos_a),              .valid_out(acos_out_v), .y(acos_o));
    fp32_cos  cos_inst (.clk(clk), .rst(rst), .valid_in(cos_in_v),  .a(cos_a),           .valid_out(cos_out_v),  .y(cos_o));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_add1<=0; w_add2<=0; w_add3<=0; w_mul1<=0; w_mul2<=0; w_mul3<=0; w_mul4<=0;
            w_div1<=0; w_sqrt<=0; w_cbrt<=0; w_acos<=0; w_cos<=0;
        end else begin
            if (add1_in_v) w_add1 <= 1; else if (add1_out_v) begin w_add1 <= 0; add1_reg <= add1_o; end
            if (add2_in_v) w_add2 <= 1; else if (add2_out_v) begin w_add2 <= 0; add2_reg <= add2_o; end
            if (add3_in_v) w_add3 <= 1; else if (add3_out_v) begin w_add3 <= 0; add3_reg <= add3_o; end
            if (mul1_in_v) w_mul1 <= 1; else if (mul1_out_v) begin w_mul1 <= 0; mul1_reg <= mul1_o; end
            if (mul2_in_v) w_mul2 <= 1; else if (mul2_out_v) begin w_mul2 <= 0; mul2_reg <= mul2_o; end
            if (mul3_in_v) w_mul3 <= 1; else if (mul3_out_v) begin w_mul3 <= 0; mul3_reg <= mul3_o; end
            if (mul4_in_v) w_mul4 <= 1; else if (mul4_out_v) begin w_mul4 <= 0; mul4_reg <= mul4_o; end
            if (div1_in_v) w_div1 <= 1; else if (div1_out_v) begin w_div1 <= 0; div1_reg <= div1_o; end
            if (sqrt_in_v) w_sqrt <= 1; else if (sqrt_out_v) begin w_sqrt <= 0; sqrt_reg <= sqrt_o; end
            if (cbrt_in_v) w_cbrt <= 1; else if (cbrt_out_v) begin w_cbrt <= 0; cbrt_reg <= cbrt_o; end
            if (acos_in_v) w_acos <= 1; else if (acos_out_v) begin w_acos <= 0; acos_reg <= acos_o; end
            if (cos_in_v)  w_cos  <= 1; else if (cos_out_v)  begin w_cos  <= 0; cos_reg  <= cos_o;  end
        end
    end
    
    reg [5:0] state;
    localparam [5:0] 
        IDLE=0, S_P1=1, S_P2=2, S_P3=3, S_P4=4, S_P5=5, S_P6=6, S_P7=7, S_P8=8, S_P9=9, S_P10=10,
        S_C1=11, S_C2=12, S_C3A=13, S_C3B=14, S_C4=15, S_C5=16, S_C6=17, S_C7=18,
        S_T1=19, S_T2A=20, S_T2B=21, S_T3=22, S_T4=23, S_T5=24, S_T6=25, 
        S_T7A=26, S_T7B=27, S_T7C=28, S_T8=29, S_T9=30, S_T10=31;

    reg [1:0] step;

    reg [31:0] a2, b2, ac, ad, a_3, a3, ac3, b3, a2d, b_3a, b3_2, ac9, a2d27, a2_3, p_num;
    reg [31:0] abc9, a3_27, p, q_part1, q_num, p2, q, p3, q2, p3_27, q2_4, D;
    reg [31:0] D_sqrt, q_half_neg, u_arg, v_arg, u, v, u_plus_v, u_minus_v, t12_re, t1_im, x12_re;
    reg [31:0] r_ins, p_m_1_3, r, sqrt_p_m_1_3, acos_arg, r_mul, theta, theta_3;
    reg [31:0] theta_3_m, theta_3_p, cos0, cos1, cos2, t0, t1, t2;

    wire D_is_neg = D[31] && (D[30:0] != 31'd0); 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; valid <= 0; error <= 0; step <= 0;
            x0_re<=FP_NAN; x0_im<=FP_NAN; x1_re<=FP_NAN; x1_im<=FP_NAN; x2_re<=FP_NAN; x2_im<=FP_NAN;
        end else begin
            add1_in_v<=0; add2_in_v<=0; add3_in_v<=0; mul1_in_v<=0; mul2_in_v<=0; mul3_in_v<=0; mul4_in_v<=0;
            div1_in_v<=0; sqrt_in_v<=0; cbrt_in_v<=0; acos_in_v<=0; cos_in_v<=0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        valid <= 0;
                        if (a[30:0] == 31'd0) begin error <= 1; valid <= 1; end 
                        else begin error <= 0; state <= S_P1; step <= 0; end
                    end
                end
                
                S_P1: begin 
                    if (step == 0) begin
                        mul1_a<=a; mul1_b<=a; mul1_in_v<=1; mul2_a<=b; mul2_b<=b; mul2_in_v<=1;
                        mul3_a<=a; mul3_b<=c; mul3_in_v<=1; mul4_a<=FP_3_0; mul4_b<=a; mul4_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        a2<=mul1_reg; b2<=mul2_reg; ac<=mul3_reg; a_3<=mul4_reg;
                        step <= 0; state <= S_P2;
                    end
                end
                
                S_P2: begin 
                    if (step == 0) begin
                        mul1_a<=a2; mul1_b<=a; mul1_in_v<=1; mul2_a<=FP_3_0; mul2_b<=ac; mul2_in_v<=1;
                        mul3_a<=b2; mul3_b<=b; mul3_in_v<=1; mul4_a<=a2; mul4_b<=d; mul4_in_v<=1;
                        div1_a<=b; div1_b<=a_3; div1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        a3<=mul1_reg; ac3<=mul2_reg; b3<=mul3_reg; a2d<=mul4_reg; b_3a<=div1_reg;
                        step <= 0; state <= S_P3;
                    end
                end
                
                S_P3: begin 
                    if (step == 0) begin
                        mul1_a<=FP_2_0; mul1_b<=b3; mul1_in_v<=1; mul2_a<=FP_9_0; mul2_b<=ac; mul2_in_v<=1;
                        mul3_a<=FP_27_0; mul3_b<=a2d; mul3_in_v<=1; mul4_a<=FP_3_0; mul4_b<=a2; mul4_in_v<=1;
                        add1_a<=ac3; add1_b<={~b2[31], b2[30:0]}; add1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        b3_2<=mul1_reg; ac9<=mul2_reg; a2d27<=mul3_reg; a2_3<=mul4_reg; p_num<=add1_reg;
                        step <= 0; state <= S_P4;
                    end
                end
                
                S_P4: begin 
                    if (step == 0) begin
                        mul1_a<=ac9; mul1_b<=b; mul1_in_v<=1; mul2_a<=FP_27_0; mul2_b<=a3; mul2_in_v<=1;
                        div1_a<=p_num; div1_b<=a2_3; div1_in_v<=1; add1_a<=b3_2; add1_b<=a2d27; add1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        abc9<=mul1_reg; a3_27<=mul2_reg; p<=div1_reg; q_part1<=add1_reg;
                        step <= 0; state <= S_P5;
                    end
                end
                
                S_P5: begin 
                    if (step == 0) begin
                        add1_a<=q_part1; add1_b<={~abc9[31], abc9[30:0]}; add1_in_v<=1;
                        mul1_a<=p; mul1_b<=p; mul1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        q_num<=add1_reg; p2<=mul1_reg;
                        step <= 0; state <= S_P6;
                    end
                end
                
                S_P6: begin 
                    if (step == 0) begin
                        div1_a<=q_num; div1_b<=a3_27; div1_in_v<=1; mul1_a<=p2; mul1_b<=p; mul1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        q<=div1_reg; p3<=mul1_reg;
                        step <= 0; state <= S_P7;
                    end
                end
                
                S_P7: begin 
                    if (step == 0) begin
                        mul1_a<=q; mul1_b<=q; mul1_in_v<=1; mul2_a<=p3; mul2_b<=FP_1_27; mul2_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        q2<=mul1_reg; p3_27<=mul2_reg;
                        step <= 0; state <= S_P8;
                    end
                end
                
                S_P8: begin 
                    if (step == 0) begin
                        mul1_a<=q2; mul1_b<=FP_0_25; mul1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        q2_4<=mul1_reg;
                        step <= 0; state <= S_P9;
                    end
                end
                
                S_P9: begin 
                    if (step == 0) begin
                        add1_a<=q2_4; add1_b<=p3_27; add1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        D<=add1_reg;
                        step <= 0; state <= S_P10;
                    end
                end
                
                S_P10: begin if (D_is_neg) state<=S_T1; else state<=S_C1; end
                
                S_C1: begin 
                    if (step == 0) begin
                        sqrt_a<=D; sqrt_in_v<=1; mul1_a<=q; mul1_b<=FP_M0_5; mul1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        D_sqrt<=sqrt_reg; q_half_neg<=mul1_reg;
                        step <= 0; state <= S_C2;
                    end
                end
                
                S_C2: begin 
                    if (step == 0) begin
                        add1_a<=q_half_neg; add1_b<=D_sqrt; add1_in_v<=1;
                        add2_a<=q_half_neg; add2_b<={~D_sqrt[31], D_sqrt[30:0]}; add2_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        u_arg<=add1_reg; v_arg<=add2_reg;
                        step <= 0; state <= S_C3A;
                    end
                end
                
                S_C3A: begin 
                    if (step == 0) begin cbrt_a<=u_arg; cbrt_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin u<=cbrt_reg; step <= 0; state <= S_C3B; end
                end
                
                S_C3B: begin 
                    if (step == 0) begin cbrt_a<=v_arg; cbrt_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin v<=cbrt_reg; step <= 0; state <= S_C4; end
                end
                
                S_C4: begin 
                    if (step == 0) begin
                        add1_a<=u; add1_b<=v; add1_in_v<=1; add2_a<=u; add2_b<={~v[31], v[30:0]}; add2_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        u_plus_v<=add1_reg; u_minus_v<=add2_reg;
                        step <= 0; state <= S_C5;
                    end
                end
                
                S_C5: begin 
                    if (step == 0) begin
                        mul1_a<=u_plus_v; mul1_b<=FP_M0_5; mul1_in_v<=1;
                        mul2_a<=u_minus_v; mul2_b<=FP_SQRT3_2; mul2_in_v<=1;
                        add1_a<=u_plus_v; add1_b<={~b_3a[31], b_3a[30:0]}; add1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        t12_re<=mul1_reg; t1_im<=mul2_reg; x0_re<=add1_reg;
                        step <= 0; state <= S_C6;
                    end
                end
                
                S_C6: begin 
                    if (step == 0) begin
                        add1_a<=t12_re; add1_b<={~b_3a[31], b_3a[30:0]}; add1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        x12_re<=add1_reg;
                        step <= 0; state <= S_C7;
                    end
                end
                
                S_C7: begin 
                    x0_im <= FP_0_0; x1_re <= x12_re; x1_im <= t1_im; 
                    x2_re <= x12_re; x2_im <= (t1_im[30:0]==0) ? FP_0_0 : {~t1_im[31], t1_im[30:0]}; 
                    valid <= 1; state <= IDLE; 
                end
                
                S_T1: begin 
                    if (step == 0) begin
                        mul1_a<=p3_27; mul1_b<=FP_M1_0; mul1_in_v<=1; mul2_a<=q; mul2_b<=FP_M0_5; mul2_in_v<=1;
                        mul3_a<=p; mul3_b<=FP_M1_3; mul3_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        r_ins<=mul1_reg; q_half_neg<=mul2_reg; p_m_1_3<=mul3_reg;
                        step <= 0; state <= S_T2A;
                    end
                end
                
                S_T2A: begin 
                    if (step == 0) begin sqrt_a<=r_ins; sqrt_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin r<=sqrt_reg; step <= 0; state <= S_T2B; end
                end
                
                S_T2B: begin 
                    if (step == 0) begin sqrt_a<=p_m_1_3; sqrt_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin sqrt_p_m_1_3<=sqrt_reg; step <= 0; state <= S_T3; end
                end
                
                S_T3: begin 
                    if (step == 0) begin
                        div1_a<=q_half_neg; div1_b<=r; div1_in_v<=1; mul1_a<=sqrt_p_m_1_3; mul1_b<=FP_2_0; mul1_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        acos_arg<=div1_reg; r_mul<=mul1_reg;
                        step <= 0; state <= S_T4;
                    end
                end
                
                S_T4: begin 
                    if (step == 0) begin acos_a<=acos_arg; acos_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin theta<=acos_reg; step <= 0; state <= S_T5; end
                end
                
                S_T5: begin 
                    if (step == 0) begin mul1_a<=theta; mul1_b<=FP_1_3; mul1_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin theta_3<=mul1_reg; step <= 0; state <= S_T6; end
                end
                
                S_T6: begin 
                    if (step == 0) begin
                        add1_a<=theta_3; add1_b<={~FP_2PI_3[31], FP_2PI_3[30:0]}; add1_in_v<=1;
                        add2_a<=theta_3; add2_b<=FP_2PI_3; add2_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        theta_3_m<=add1_reg; theta_3_p<=add2_reg;
                        step <= 0; state <= S_T7A;
                    end
                end
                
                S_T7A: begin 
                    if (step == 0) begin cos_a<=theta_3; cos_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin cos0<=cos_reg; step <= 0; state <= S_T7B; end
                end
                
                S_T7B: begin 
                    if (step == 0) begin cos_a<=theta_3_m; cos_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin cos1<=cos_reg; step <= 0; state <= S_T7C; end
                end
                
                S_T7C: begin 
                    if (step == 0) begin cos_a<=theta_3_p; cos_in_v<=1; step <= 1; 
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin cos2<=cos_reg; step <= 0; state <= S_T8; end
                end
                
                S_T8: begin 
                    if (step == 0) begin
                        mul1_a<=r_mul; mul1_b<=cos0; mul1_in_v<=1;
                        mul2_a<=r_mul; mul2_b<=cos1; mul2_in_v<=1;
                        mul3_a<=r_mul; mul3_b<=cos2; mul3_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        t0<=mul1_reg; t1<=mul2_reg; t2<=mul3_reg;
                        step <= 0; state <= S_T9;
                    end
                end
                
                S_T9: begin 
                    if (step == 0) begin
                        add1_a<=t0; add1_b<={~b_3a[31], b_3a[30:0]}; add1_in_v<=1;
                        add2_a<=t1; add2_b<={~b_3a[31], b_3a[30:0]}; add2_in_v<=1;
                        add3_a<=t2; add3_b<={~b_3a[31], b_3a[30:0]}; add3_in_v<=1;
                        step <= 1;
                    end else if (step == 1) begin step <= 2;
                    end else if (step == 2 && all_done) begin
                        x0_re<=add1_reg; x1_re<=add2_reg; x2_re<=add3_reg;
                        step <= 0; state <= S_T10;
                    end
                end
                
                S_T10: begin 
                    x0_re<=x0_re; x1_re<=x1_re; x2_re<=x2_re;
                    x0_im<=FP_0_0; x1_im<=FP_0_0; x2_im<=FP_0_0; 
                    valid<=1; state<=IDLE; 
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule