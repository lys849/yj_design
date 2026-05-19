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

    // 100MHz clock (10ns period)
    always #5 clk = ~clk;

    // UART receive monitor
    localparam BIT_PERIOD = 8680;

    reg [7:0]      rx_byte;
    reg [8*40:1]   msg_buf;
    reg [5:0]      msg_pos;
    integer        i;

    initial begin
        msg_buf = 0;
        msg_pos = 0;
    end

    always begin
        @(negedge debug_tx);
        #(BIT_PERIOD / 2);
        for (i = 0; i < 8; i = i + 1) begin
            #(BIT_PERIOD);
            rx_byte[i] = debug_tx;
        end
        #(BIT_PERIOD);  // stop bit
        #1;

        if (rx_byte >= 32 && rx_byte < 127) begin
            msg_buf = {msg_buf, rx_byte};
            msg_pos = msg_pos + 1;
        end else if (rx_byte == 8'd10) begin  // LF
            $display("[UART] %s", msg_buf);
            msg_buf = 0;
            msg_pos = 0;
        end
    end

    initial begin
        $display("=== Nexys4 DDR Board Self-Test ===\n");
        clk  = 0; btnc = 0; rst_n = 0;
        #100 rst_n = 1;
        #200000;  // 200us — first char arrives ~125us
        $display("Stopping early for debug.");
        $finish;
    end

endmodule
