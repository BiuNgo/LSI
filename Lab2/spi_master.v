`timescale 1ns / 1ps

module spi_master(
    input  wire       REFCLK,
    input  wire [7:0] INPUT,
    input  wire [1:0] CNTL,
    output reg  [7:0] OUTPUT,
    output reg        READY,
    
    output wire       MOSI,
    input  wire       MISO,
    output reg        SCLK,
    output reg  [7:0] SS
    );

    reg [7:0] curr_ss;
    reg [2:0] bit_cnt;
    reg [2:0] state;
    reg       miso_buf;
    
    localparam IDLE      = 3'd0,
               START     = 3'd1,
               SCLK_HIGH = 3'd2,
               SCLK_LOW  = 3'd3,
               DONE      = 3'd4,
               WAIT      = 3'd5;
    
    assign MOSI = OUTPUT[7];
    
    initial begin
        READY   = 1'b1;
        SCLK    = 1'b0;
        SS      = 8'hFF;
        curr_ss = 8'hFF;
        state   = IDLE;
        OUTPUT  = 8'h0;
    end
    
    always @(posedge REFCLK) begin
        case (state)
            IDLE: begin
                SCLK <= 0;
                SS   <= 8'hFF;
                
                if (CNTL == 2'b01) begin
                    OUTPUT <= INPUT;
                end else if (CNTL == 2'b10) begin
                    if (INPUT < 8) begin
                        curr_ss <= ~(8'b00000001 << INPUT);
                    end else begin
                        curr_ss <= 8'hFF;
                    end
                end else if (CNTL == 2'b11) begin
                    READY <= 1'b0;
                    state <= START;
                end
            end
            
            START: begin
                SS      <= curr_ss;
                bit_cnt <= 3'd0;
                state   <= SCLK_HIGH;
            end
            
            SCLK_HIGH: begin
                SCLK     <= 1'b1;
                miso_buf <= MISO;
                state    <= SCLK_LOW;
            end
            
            SCLK_LOW: begin
                SCLK <= 1'b0;
                OUTPUT <= {OUTPUT[6:0], miso_buf};
                
                if (bit_cnt == 3'd7) begin
                    state <= DONE;
                end else begin
                    bit_cnt <= bit_cnt + 1'b1;
                    state   <= SCLK_HIGH;
                end
            end
            
            DONE: begin
                SS <= 8'hFF;
                state <= WAIT;
            end
            
            WAIT: begin
                if (CNTL != 2'b11) begin
                    READY <= 1'b1;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
endmodule
