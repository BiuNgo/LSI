`timescale 1ns / 1ps

module spi_slave(
    input  wire [7:0] INPUT,
    input  wire       LOAD,
    output reg  [7:0] OUTPUT,
    output wire       READY,
    
    output wire       MISO,
    input  wire       MOSI,
    input  wire       SCLK,
    input  wire       CS
    );

    reg mosi_buf;
    
    assign READY = CS;
    
    assign MISO = (!CS) ? OUTPUT[7] : 1'bz;
    
    always @(posedge SCLK) begin
        if (!CS) begin
            mosi_buf <= MOSI;
        end
    end
    
    always @(negedge SCLK or posedge LOAD) begin
        if (LOAD) begin
            if (READY) begin
                OUTPUT <= INPUT;
            end
        end else if (!CS) begin
            OUTPUT <= {OUTPUT[6:0], mosi_buf};
        end
    end
endmodule
