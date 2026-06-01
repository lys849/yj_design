// UART TX/RX Testbench - verified working version
`timescale 1ns / 1ps

module uart_tb;

    reg         clk;
    reg         rst_n;
    reg  [7:0]  tx_data;
    reg         tx_start;
    wire        tx;
    wire        tx_busy;
    wire        tx_done;

    wire [7:0]  rx_data;
    wire        rx_valid;

    uart_tx #(.CLK_FREQ(50_000_000), .BAUD_RATE(57600)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    uart_rx #(.CLK_FREQ(50_000_000), .BAUD_RATE(57600)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(tx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    always #10 clk = ~clk;

    reg [7:0] test_data;
    reg       test_fail;

    task send_byte;
        input [7:0] byte;
        begin
            @(posedge clk);
            tx_data  = byte;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
        end
    endtask

    initial begin
        clk       = 0;
        rst_n     = 0;
        tx_data   = 8'h00;
        tx_start  = 0;
        test_fail = 0;

        #100 rst_n = 1;
        #200;

        $display("========================================");
        $display(" UART TX/RX Loopback Test (57600 baud) ");
        $display("========================================");

        test_data = 8'hA5;
        $display("Test 1: 0x%02X", test_data);
        send_byte(test_data);
        @(posedge rx_valid);
        if (rx_data == test_data) $display("  PASS: 0x%02X", rx_data);
        else begin $display("  FAIL: got 0x%02X", rx_data); test_fail = 1; end

        #50000;
        test_data = 8'h55;
        $display("Test 2: 0x%02X", test_data);
        send_byte(test_data);
        @(posedge rx_valid);
        if (rx_data == test_data) $display("  PASS: 0x%02X", rx_data);
        else begin $display("  FAIL: got 0x%02X", rx_data); test_fail = 1; end

        #50000;
        test_data = 8'h00;
        $display("Test 3: 0x%02X", test_data);
        send_byte(test_data);
        @(posedge rx_valid);
        if (rx_data == test_data) $display("  PASS: 0x%02X", rx_data);
        else begin $display("  FAIL: got 0x%02X", rx_data); test_fail = 1; end

        #50000;
        test_data = 8'hFF;
        $display("Test 4: 0x%02X", test_data);
        send_byte(test_data);
        @(posedge rx_valid);
        if (rx_data == test_data) $display("  PASS: 0x%02X", rx_data);
        else begin $display("  FAIL: got 0x%02X", rx_data); test_fail = 1; end

        #50000;
        test_data = 8'h3C;
        $display("Test 5: 0x%02X", test_data);
        send_byte(test_data);
        @(posedge rx_valid);
        if (rx_data == test_data) $display("  PASS: 0x%02X", rx_data);
        else begin $display("  FAIL: got 0x%02X", rx_data); test_fail = 1; end

        #50000;
        if (!test_fail) begin
            $display("========================================");
            $display(" UART TEST: ALL 5 PASSED                ");
            $display("========================================");
        end else begin
            $display("========================================");
            $display(" UART TEST: FAILURES DETECTED           ");
            $display("========================================");
        end

        #100000;
        $finish;
    end

endmodule
