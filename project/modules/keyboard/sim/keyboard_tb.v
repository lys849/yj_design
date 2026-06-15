// Keyboard Scanner Testbench — simulates key press with proper timing
`timescale 1ns / 1ps

module keyboard_tb;
    reg        clk = 0;
    reg        rst_n = 0;
    wire [3:0] row;
    reg  [3:0] col;
    wire [3:0] key_code;
    wire       key_valid;

    always #5 clk = ~clk; // 100 MHz

    keyboard_scan #(
        .CLK_FREQ(100_000_000),
        .DWELL_US(10),        // shorter for simulation
        .DEBOUNCE_MS(1)       // shorter for simulation
    ) uut (
        .clk(clk), .rst_n(rst_n),
        .row(row), .col(col),
        .key_code(key_code), .key_valid(key_valid)
    );

    integer pass_cnt = 0;

    task press_key(input [1:0] target_row, input [1:0] target_col);
        begin
            $display("  Pressing key: row=%0d col=%0d (expected code=%0d)",
                     target_row, target_col, target_row*4 + target_col);
            // Wait until scanner drives the target row low
            wait (row[target_row] == 1'b0);
            #100; // settling time
            col = 4'hF;
            col[target_col] = 1'b0; // press: col goes low
            wait (key_valid);
            @(posedge clk);
            $display("    Got key_code=%0d, expected=%0d -> %s",
                     key_code, target_row*4+target_col,
                     (key_code == target_row*4+target_col) ? "PASS" : "FAIL");
            if (key_code == target_row*4+target_col) pass_cnt = pass_cnt + 1;
            // Release
            #200_000;
            col = 4'hF;
            #500_000;
        end
    endtask

    initial begin
        col = 4'hF;
        #200 rst_n = 1;
        #1000;

        $display("=== Keyboard Scanner Test ===");
        press_key(2'd0, 2'd0); // key 0
        press_key(2'd1, 2'd2); // key 6
        press_key(2'd3, 2'd3); // key 15

        $display("=== Result: %0d/3 passed ===", pass_cnt);
        $finish;
    end
endmodule
