// UART TX→RX Loopback Testbench
`timescale 1ns / 1ps

module uart_tb;
    reg        clk = 0;
    reg        rst_n = 0;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy, tx_done, tx_line;
    wire [7:0] rx_data;
    wire       rx_valid;

    always #5 clk = ~clk; // 100 MHz

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(tx_line), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    uart_rx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(tx_line), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task send_and_check(input [7:0] data);
        begin
            @(posedge clk);
            tx_data  = data;
            tx_start = 1;
            @(posedge clk);
            tx_start = 0;
            wait (rx_valid);
            @(posedge clk);
            if (rx_data == data) begin
                $display("  PASS: sent=%02x received=%02x", data, rx_data);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL: sent=%02x received=%02x", data, rx_data);
                fail_cnt = fail_cnt + 1;
            end
            #1000;
        end
    endtask

    initial begin
        #100 rst_n = 1;
        #100;
        tx_start = 0;

        $display("=== UART Loopback Test (115200 baud, 100MHz) ===");
        send_and_check(8'hA5);
        send_and_check(8'h00);
        send_and_check(8'hFF);
        send_and_check(8'h55);
        send_and_check(8'h3C);

        $display("=== Result: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end
endmodule
