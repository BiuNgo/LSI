`timescale 1ns / 1ps

module ring_flasher(
    input wire clk,
    input wire rst_n,
    input wire repeat_signal,
    output reg [15:0] led
    );
    
    localparam IDLE = 2'd0;
    localparam UP = 2'd1;
    localparam DOWN = 2'd2;
    
    reg [1:0] state;
    reg [3:0] ptr;
    reg [2:0] cycle;
    reg [2:0] step;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led <= 16'b0;
            state <= IDLE;
            ptr <= 4'b0;
            cycle <= 3'b0;
            step <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (repeat_signal)
                        state <= UP;
                end
                
                UP: begin
                    led[ptr] <= ~led[ptr];
                    
                    if (step == 3'd7) begin
                        state <= DOWN;
                        step <= 3'b0;
                    end else begin
                        step <= step + 1'b1;
                        ptr <= ptr + 1'b1;
                    end
                end
                
                DOWN: begin
                    led[ptr] <= ~led[ptr];
                    
                    if (step == 3'd3) begin
                        step <= 3'b0;
                        cycle <= cycle + 1'b1;
                        
                        if (cycle == 3'd7) begin
                            if (repeat_signal) begin
                                state <= UP;
                            end else begin
                                state <= IDLE;
                            end
                        end else begin
                            state <= UP;
                        end
                    end else begin
                        step <= step + 1'b1;
                        ptr <= ptr - 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
