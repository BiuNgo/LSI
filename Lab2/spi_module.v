`timescale 1ns / 1ps

//`include "spi_master.v"
//`include "spi_slave.v"

module spi_module(
    input wire REFCLK,
    
    input  wire [7:0] M_INPUT,
    input  wire [1:0] M_CNTL,
    output wire [7:0] M_OUTPUT,
    output wire       M_READY,
    
    input  wire [7:0] S_INPUT,
    input  wire       S_LOAD,
    output wire [7:0] S_OUTPUT,
    output wire       S_READY,
    
    output wire [7:0] unused_ss
    );
    
    wire w_mosi;
    wire w_miso;
    wire w_sclk;
    wire [7:0] w_ss;
    
    assign unused_ss = w_ss[7:1];
    
    spi_master m_inst (
        .REFCLK(REFCLK),
        .INPUT(M_INPUT),
        .CNTL(M_CNTL),
        .OUTPUT(M_OUTPUT),
        .READY(M_READY),
        .MOSI(w_mosi),
        .MISO(w_miso),
        .SCLK(w_sclk),
        .SS(w_ss)
    );
    
    spi_slave s_inst (
        .INPUT(S_INPUT),
        .LOAD(S_LOAD),
        .OUTPUT(S_OUTPUT),
        .READY(S_READY),
        .MISO(w_miso),
        .MOSI(w_mosi),
        .SCLK(w_sclk),
        .CS(w_ss[0])
    );
endmodule
