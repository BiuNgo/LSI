`timescale 1ns / 1ps

module tb_spi_master();
    reg       REFCLK;
    reg [7:0] INPUT;
    reg [1:0] CNTL;
    reg       MISO;

    wire [7:0] OUTPUT;
    wire       READY;
    wire       MOSI;
    wire       SCLK;
    wire [7:0] SS;

    spi_master uut (
        .REFCLK(REFCLK),
        .INPUT(INPUT),
        .CNTL(CNTL),
        .OUTPUT(OUTPUT),
        .READY(READY),
        .MOSI(MOSI),
        .MISO(MISO),
        .SCLK(SCLK),
        .SS(SS)
    );

    initial REFCLK = 0;
    always #5 REFCLK = ~REFCLK;

    task do_spi_transfer;
        input [7:0] slave_id;
        input [7:0] tx_data;
        input [7:0] expected_rx_data;
        
        integer k;
        begin
            @(posedge REFCLK);
            INPUT = slave_id;
            CNTL  = 2'b10;
            @(posedge REFCLK);
            CNTL  = 2'b00;

            @(posedge REFCLK);
            INPUT = tx_data;
            CNTL  = 2'b01;
            @(posedge REFCLK);
            CNTL  = 2'b00;

            @(posedge REFCLK);
            CNTL = 2'b11;
            
            @(posedge REFCLK);
            if (READY !== 1'b0) $display("[FAIL] READY did not drop to 0 on start.");

            for (k = 7; k >= 0; k = k - 1) begin
                MISO = expected_rx_data[k];
                
                wait(SCLK == 1'b1);
                if (MOSI !== tx_data[k])
                    $display("[FAIL] MOSI incorrect at bit %0d. Expected %b, got %b", k, tx_data[k], MOSI);
                    
                wait(SCLK == 1'b0);
            end

            wait(SS == 8'hFF);
            
            @(posedge REFCLK);
            CNTL = 2'b00;
            
            wait(READY == 1'b1);
            @(posedge REFCLK);

            if (OUTPUT === expected_rx_data)
                $display("[PASS] Slave %0d TX: %h | RX: %h successfully completed.", slave_id, tx_data, OUTPUT);
            else
                $display("[FAIL] Slave %0d RX failed. Expected: %h, Got: %h", slave_id, expected_rx_data, OUTPUT);
        end
    endtask

    initial begin
        INPUT = 0;
        CNTL  = 2'b00;
        MISO  = 0;

        #25;
        $display("--- Starting SPI Master Tests ---");

        $display("\nTest 1: Standard Transfer");
        do_spi_transfer(8'd0, 8'b10100101, 8'b00111100);

        $display("\nTest 2: All Zeros Transfer (Slave 7)");
        do_spi_transfer(8'd7, 8'h00, 8'h00);
        
        $display("\nTest 3: All Ones Transfer (Slave 3)");
        do_spi_transfer(8'd3, 8'hFF, 8'hFF);

        $display("\nTest 4: Alternating Bits (Slave 5)");
        do_spi_transfer(8'd5, 8'hAA, 8'h55);

        $display("\nTest 5: Back-to-Back Transfers");
        do_spi_transfer(8'd1, 8'h12, 8'h34);
        do_spi_transfer(8'd1, 8'h56, 8'h78);

        $display("\nTest 6: Invalid Slave Selection (INPUT = 9)");
        @(posedge REFCLK);
        INPUT = 8'd9;  
        CNTL  = 2'b10;
        @(posedge REFCLK);
        CNTL  = 2'b00;
        @(posedge REFCLK);
        
        CNTL  = 2'b11;
        @(posedge REFCLK);
        @(posedge REFCLK);
        
        if (SS === 8'hFF) $display("[PASS] Out-of-range slave selection handled safely (SS=0xFF).");
        else $display("[FAIL] Out-of-range slave altered SS. Got: %b", SS);
        
        CNTL = 2'b00;
        
        wait(READY == 1'b1);
        
        $display("\nTest 7: Releasing CNTL start command mid-transfer");
        @(posedge REFCLK);
        INPUT = 8'd2; CNTL = 2'b10; @(posedge REFCLK);
        INPUT = 8'h99; CNTL = 2'b01; @(posedge REFCLK);
        CNTL = 2'b11;
        
        wait(SCLK == 1'b1); wait(SCLK == 1'b0);
        wait(SCLK == 1'b1); wait(SCLK == 1'b0);
        wait(SCLK == 1'b1); wait(SCLK == 1'b0);
        @(posedge REFCLK);
        
        CNTL = 2'b00;
        
        wait(SS == 8'hFF);
        @(posedge REFCLK);
        
        @(posedge REFCLK); 
        
        if (READY === 1'b1) 
            $display("[PASS] Master completed mid-flight transfer and safely returned to READY.");
        else 
            $display("[FAIL] Master got stuck when CNTL was released early.");

        #50;
        $display("\n--- SPI Master Testbench Complete ---");
        $finish;
    end
endmodule