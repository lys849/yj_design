// test_board_tb.v — Simulation testbench for full payment system test
`timescale 1ns / 1ps

module test_board_tb;
    reg        clk;
    reg        rst_n;
    wire       debug_tx;
    wire [3:0] kb_row, kb_col;
    wire       fp_sensor_tx, fp_sensor_rx;
    wire       buzzer;

    reg [3:0]  kb_col_reg;
    assign kb_col = kb_col_reg;

    test_board uut (
        .clk_100mhz(clk), .rst_n(rst_n),
        .debug_tx(debug_tx),
        .kb_row(kb_row), .kb_col(kb_col),
        .fp_sensor_tx(fp_sensor_tx), .fp_sensor_rx(fp_sensor_rx),
        .buzzer(buzzer)
    );

    // 100MHz clock
    always #5 clk = ~clk;

    // UART TX monitor (115200 baud)
    localparam BIT_PERIOD = 8680;
    reg [7:0] rx_byte;
    integer   i;

    // For simplicity, loopback fp_sensor_tx to fp_sensor_rx
    // so fingerprint commands are echoed back (simulates working sensor)
    assign fp_sensor_rx = fp_sensor_tx;

    always begin
        @(negedge debug_tx);
        #(BIT_PERIOD / 2);
        for (i = 0; i < 8; i = i + 1) begin
            #(BIT_PERIOD);
            rx_byte[i] = debug_tx;
        end
        #(BIT_PERIOD);
        #1;
        if (rx_byte >= 32 && rx_byte < 127)
            $write("%c", rx_byte);
        else if (rx_byte == 8'h0A)
            $write("\n");
    end

    // Simulate keyboard: press keys at specific times
    task press_key;
        input [3:0] key;
        input [31:0] delay_ns;
        integer k;
        begin
            #delay_ns;
            // Scan row: wait for active row, drive column
            @(posedge clk);
            // Simulate key press: set col according to row
            if (kb_row[0] == 0) kb_col_reg <= 4'b1110;
            else if (kb_row[1] == 0) kb_col_reg <= 4'b1101;
            else if (kb_row[2] == 0) kb_col_reg <= 4'b1011;
            else if (kb_row[3] == 0) kb_col_reg <= 4'b0111;
            else kb_col_reg <= 4'hF;

            // Hold for 25ms (debounce)
            #25000000;
            kb_col_reg <= 4'hF;
            #1000000;
        end
    endtask

    initial begin
        $display("=== Full System Test ===\n");

        clk = 0; kb_col_reg = 4'hF; rst_n = 0;
        #100 rst_n = 1;

        // Wait for init + main menu
        #5000000;  // 5ms

        // Press 2 to go to Payment
        // (Simplified: just wait and check output)
        
        // Wait for complete sequence
        #2000000000;  // 2 seconds
        
        $display("\n=== Test Done ===");
        $finish;
    end
endmodule
