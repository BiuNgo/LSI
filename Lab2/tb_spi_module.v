`timescale 1ns / 1ps

module tb_spi_module();
    reg       REFCLK;
    reg [7:0] M_INPUT;
    reg [1:0] M_CNTL;
    reg [7:0] S_INPUT;
    reg       S_LOAD;

    wire [7:0] M_OUTPUT;
    wire       M_READY;
    wire [7:0] S_OUTPUT;
    wire       S_READY;
    wire [7:0] unused_ss;

    wire [7:0] master_ss = {unused_ss, S_READY};

    spi_module uut (
        .REFCLK(REFCLK),
        .M_INPUT(M_INPUT),
        .M_CNTL(M_CNTL),
        .M_OUTPUT(M_OUTPUT),
        .M_READY(M_READY),
        .S_INPUT(S_INPUT),
        .S_LOAD(S_LOAD),
        .S_OUTPUT(S_OUTPUT),
        .S_READY(S_READY),
        .unused_ss(unused_ss)
    );

    initial REFCLK = 0;
    always #5 REFCLK = ~REFCLK;

    task do_full_transfer(input [2:0] slave_target, input [7:0] m_tx_data, input [7:0] s_tx_data);
        begin
            @(posedge REFCLK);
            S_INPUT = s_tx_data;
            S_LOAD  = 1;
            @(posedge REFCLK);
            S_LOAD  = 0;
            
            @(posedge REFCLK);
            M_INPUT = {5'b0, slave_target};
            M_CNTL  = 2'b10;
            @(posedge REFCLK);
            M_CNTL  = 2'b00;

            @(posedge REFCLK);
            M_INPUT = m_tx_data;
            M_CNTL  = 2'b01;
            @(posedge REFCLK);
            M_CNTL  = 2'b00;

            @(posedge REFCLK);
            M_CNTL = 2'b11;

            wait(master_ss != 8'hFF);

            wait(master_ss == 8'hFF);

            @(posedge REFCLK);
            M_CNTL = 2'b00;
            wait(M_READY == 1'b1);
            @(posedge REFCLK);

            if (slave_target == 3'd0) begin
                if (M_OUTPUT === s_tx_data && S_OUTPUT === m_tx_data)
                    $display("[PASS] Target: %0d | Master sent %h, received %h | Slave sent %h, received %h", 
                              slave_target, m_tx_data, M_OUTPUT, s_tx_data, S_OUTPUT);
                else
                    $display("[FAIL] Loopback error! Master got %h (Exp %h). Slave got %h (Exp %h).", 
                              M_OUTPUT, s_tx_data, S_OUTPUT, m_tx_data);
            end else begin
                if (S_OUTPUT === s_tx_data)
                    $display("[PASS] Target: %0d | Unselected slave successfully ignored transfer (Kept %h). Master read floating bus: %b", 
                              slave_target, S_OUTPUT, M_OUTPUT);
                else
                    $display("[FAIL] Unselected Slave was corrupted! Got %h (Expected to keep %h)", S_OUTPUT, s_tx_data);
            end
        end
    endtask

    initial begin
        M_INPUT = 0;
        M_CNTL  = 2'b00;
        S_INPUT = 0;
        S_LOAD  = 0;

        #25;
        $display("--- Starting Top-Level SPI Testbench ---");

        $display("\nTest 1: Standard Loopback");
        do_full_transfer(3'd0, 8'h55, 8'hAA);

        $display("\nTest 2: All Zeros");
        do_full_transfer(3'd0, 8'h00, 8'h00);

        $display("\nTest 3: All Ones");
        do_full_transfer(3'd0, 8'hFF, 8'hFF);

        $display("\nTest 4: Back-to-Back Transfers");
        do_full_transfer(3'd0, 8'h12, 8'h34);
        do_full_transfer(3'd0, 8'h56, 8'h78);

        $display("\nTest 5: Target Slave 3 (Slave 0 should ignore)");
        do_full_transfer(3'd3, 8'h99, 8'h33);

        $display("\nTest 6: Malicious S_LOAD during active transfer");
        
        @(posedge REFCLK);
        S_INPUT = 8'h22; S_LOAD = 1; @(posedge REFCLK); S_LOAD = 0;
        M_INPUT = 8'd0; M_CNTL = 2'b10; @(posedge REFCLK); M_CNTL = 2'b00;
        M_INPUT = 8'hCC; M_CNTL = 2'b01; @(posedge REFCLK); M_CNTL = 2'b00;
        
        M_CNTL = 2'b11;
        wait(master_ss != 8'hFF);
        
        #80; 
        
        S_INPUT = 8'h99; 
        S_LOAD = 1; 
        @(posedge REFCLK); 
        S_LOAD = 0;
        
        wait(master_ss == 8'hFF);
        @(posedge REFCLK);
        M_CNTL = 2'b00;
        wait(M_READY == 1'b1);
        @(posedge REFCLK);
        
        if (S_OUTPUT === 8'hCC)
            $display("[PASS] Slave successfully blocked malicious mid-transfer LOAD and safely captured 0xCC.");
        else
            $display("[FAIL] Slave data was corrupted during malicious LOAD! Got: %h", S_OUTPUT);

        #50;
        $display("\n--- Top-Level SPI Testbench Complete ---");
        $finish;
    end
endmodule