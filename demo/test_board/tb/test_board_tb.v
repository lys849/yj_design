// test_board_tb.v — Simulation testbench for Nexys4 DDR Board Self-Test
`timescale 1ns / 1ps

module test_board_tb;

    reg        clk;
    reg        rst_n;
    reg        btnc;
    wire       debug_tx;
    wire [3:0] led;

    test_board uut (
        .clk_100mhz(clk),
        .rst_n     (rst_n),
        .btnc      (btnc),
        .debug_tx  (debug_tx),
        .led       (led)
    );

    always #5 clk = ~clk;

    localparam BIT_PERIOD = 8680;

    reg [7:0]   rx_byte;
    reg [7:0]   rx_buf [0:63];
    reg [5:0]   rx_cnt;
    integer     i;

    initial begin
        for (i = 0; i < 64; i = i + 1) rx_buf[i] = 0;
        rx_cnt = 0;
    end

    always begin
        @(negedge debug_tx);
        #(BIT_PERIOD / 2);
        for (i = 0; i < 8; i = i + 1) begin
            #(BIT_PERIOD);
            rx_byte[i] = debug_tx;
        end
        #(BIT_PERIOD);
        #1;

        rx_buf[rx_cnt] = rx_byte;
        rx_cnt = rx_cnt + 1;
    end

    initial begin
        $display("=== Nexys4 DDR Board Self-Test ===\n");

        clk  = 0; btnc = 0; rst_n = 0;
        #100 rst_n = 1;

        #5000000;  // wait for hello
        $display("--- BTNC ---");
        btnc = 1;
        #30000000;
        btnc = 0;
        #500000;
        #10000000;  // wait for BTN msg

        $display("Received %0d bytes:", rx_cnt);
        for (i = 0; i < rx_cnt; i = i + 1) begin
            if (rx_buf[i] >= 32 && rx_buf[i] < 127)
                $write("%c", rx_buf[i]);
            else
                $write("[%02X]", rx_buf[i]);
        end
        $display("\n\n=== Done ===");
        $finish;
    end

endmodule
