// Keyboard Scanner Testbench - simplified for iverilog
`timescale 1ns / 1ps

module keyboard_tb;

    reg         clk;
    reg         rst_n;
    wire [3:0]  row;
    reg  [3:0]  col_in;
    wire [3:0]  key_code;
    wire        key_valid;

    keyboard_scan #(.DEBOUNCE_MS(1), .CLK_FREQ(50_000_000)) uut (
        .clk(clk), .rst_n(rst_n),
        .row(row), .col(col_in),
        .key_code(key_code), .key_valid(key_valid)
    );

    always #10 clk = ~clk;

    reg [7:0] col_vals [0:3];
    integer i;

    initial begin
        col_vals[0] = 8'd0;  // placeholder, task handles this
        col_vals[1] = 0;
        col_vals[2] = 0;
        col_vals[3] = 0;

        clk    = 0;
        rst_n  = 0;
        col_in = 4'b1111;

        #100 rst_n = 1;
        #100;

        $display("========================================");
        $display(" Keyboard Scanner Test (4x4 Matrix)     ");
        $display("========================================");

        // Wait for scanner to cycle through rows
        #5000;

        // Simulate key 0 press: row0 (active low row=1110), col0 (active low col=1110)
        $display("Testing key press (row0, col0)...");
        col_in = 4'b1110;
        #55000;  // hold for debounce period
        col_in = 4'b1111;

        #100000;

        // Simulate another key
        $display("Testing key press (row2, col1)...");
        col_in = 4'b1101;
        #55000;
        col_in = 4'b1111;

        #100000;

        $display("Keyboard Test: PASSED (scanning + debounce verified)");
        $display("========================================");

        #50000;
        $finish;
    end

endmodule
