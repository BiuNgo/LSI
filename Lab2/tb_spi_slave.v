`timescale 1ns / 1ps

module tb_spi_slave();
    reg [7:0] INPUT;
    reg       LOAD;
    reg       MOSI;
    reg       SCLK;
    reg       CS;

    wire [7:0] OUTPUT;
    wire       READY;
    wire       MISO;

    spi_slave uut (
        .INPUT(INPUT),
        .LOAD(LOAD),
        .OUTPUT(OUTPUT),
        .READY(READY),
        .MISO(MISO),
        .MOSI(MOSI),
        .SCLK(SCLK),
        .CS(CS)
    );

    integer i;

    task do_load_data(input [7:0] data_to_load);
        begin
            INPUT = data_to_load;
            #5 LOAD = 1;
            #10 LOAD = 0;
            #5;
            if (OUTPUT !== data_to_load)
                $display("[FAIL] Failed to LOAD data. Expected %h, Got %h", data_to_load, OUTPUT);
        end
    endtask

    task do_spi_transfer(input [7:0] mosi_data, input [7:0] expected_miso_data);
        integer k;
        begin
            if (MISO !== 1'bz) 
                $display("[FAIL] MISO is not High-Z while CS is high!");

            CS = 0;
            #10;
            
            if (MISO !== expected_miso_data[7]) 
                $display("[FAIL] Initial MISO bit incorrect. Expected %b, got %b", expected_miso_data[7], MISO);

            for (k = 7; k >= 0; k = k - 1) begin
                MOSI = mosi_data[k];
                #10;
                
                SCLK = 1;
                #10;
                
                SCLK = 0;
                #10;
                
                if (k > 0) begin
                    if (MISO !== expected_miso_data[k-1])
                        $display("[FAIL] MISO bit %d incorrect. Expected %b, got %b", k-1, expected_miso_data[k-1], MISO);
                end
            end

            CS = 1;
            #10;

            if (OUTPUT === mosi_data) 
                $display("[PASS] Slave correctly received MOSI (%h) and sent MISO (%h).", mosi_data, expected_miso_data);
            else 
                $display("[FAIL] Slave MOSI capture failed. Expected: %h, Got: %h", mosi_data, OUTPUT);
                
            if (MISO !== 1'bz) 
                $display("[FAIL] MISO did not return to High-Z after CS was de-asserted.");
        end
    endtask

    initial begin
        INPUT = 0;
        LOAD  = 0;
        MOSI  = 0;
        SCLK  = 0;
        CS    = 1;

        #20;
        $display("--- Starting SPI Slave Tests ---");

        $display("\nTest 1: Standard Transfer");
        do_load_data(8'b01011010);
        do_spi_transfer(8'b11000011, 8'b01011010);

        $display("\nTest 2: All Zeros");
        do_load_data(8'h00);
        do_spi_transfer(8'h00, 8'h00);

        $display("\nTest 3: All Ones");
        do_load_data(8'hFF);
        do_spi_transfer(8'hFF, 8'hFF);

        $display("\nTest 4: Alternating Bits (0xAA / 0x55)");
        do_load_data(8'h55);
        do_spi_transfer(8'hAA, 8'h55);

        $display("\nTest 5: Ignore SCLK when CS is High");
        do_load_data(8'h12);
        
        for (i = 0; i < 8; i = i + 1) begin
            MOSI = ~MOSI;
            SCLK = 1; #10;
            SCLK = 0; #10;
        end
        
        if (OUTPUT === 8'h12 && MISO === 1'bz) 
            $display("[PASS] Slave safely ignored SCLK and kept MISO High-Z while CS=1.");
        else 
            $display("[FAIL] Slave reacted to SCLK while CS=1. OUTPUT=%h, MISO=%b", OUTPUT, MISO);

        $display("\nTest 6: Ignore LOAD when active (CS=0 / READY=0)");
        do_load_data(8'h34);
        
        CS = 0; 
        #10;
        
        for (i = 7; i >= 4; i = i - 1) begin
            MOSI = 1'b1; #10 SCLK = 1; #10 SCLK = 0; #10;
        end
        
        INPUT = 8'h99;
        LOAD = 1; #10; LOAD = 0; #10;
        
        for (i = 3; i >= 0; i = i - 1) begin
            MOSI = 1'b1; #10 SCLK = 1; #10 SCLK = 0; #10;
        end
        
        CS = 1; 
        #10;
        
        if (OUTPUT === 8'hFF) 
            $display("[PASS] Slave successfully blocked LOAD during an active transfer.");
        else 
            $display("[FAIL] Slave data was corrupted by LOAD during active transfer. Got: %h", OUTPUT);

        $display("\n--- SPI Slave Testbench Complete ---");
        $finish;
    end
endmodule