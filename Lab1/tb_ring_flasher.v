`timescale 1ns / 1ps

module tb_ring_flasher;

    reg clk;
    reg rst_n;
    reg repeat_signal;

    // Outputs
    wire [15:0] led;

    // Instantiate the Unit Under Test (UUT)
    ring_flasher uut (
        .clk(clk),
        .rst_n(rst_n),
        .repeat_signal(repeat_signal),
        .led(led)
    );

    // Clock generation: 10ns period (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        repeat_signal = 0;

        // Print a header for our console monitor
        $display("Time\t rst_n\t repeat\t LEDs [15:0]");
        $monitor("%4t\t   %b\t    %b\t     %b", $time, rst_n, repeat_signal, led);

        // 1. Apply Reset
        #10;
        rst_n = 1; // Release reset
        
        // 2. Trigger the sequence
        #10;
        repeat_signal = 1;
        #10
        repeat_signal = 0;
        
        #500;
        rst_n = 0;
        #100;
        rst_n = 1;
        repeat_signal = 1;
        #50
        repeat_signal = 0;
        #1000;
        
        repeat_signal = 1;
        #2000;
        
        $finish;

    end

endmodule