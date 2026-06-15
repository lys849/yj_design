// Keyboard Board Test — press key → LED shows key_code[3:0]
`timescale 1ns / 1ps

module kb_test_top (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output wire [3:0] kb_row,
    input  wire [3:0] kb_col,
    output reg  [3:0] led
);

    wire [3:0] key_code;
    wire       key_valid;

    keyboard_scan #(.CLK_FREQ(100_000_000)) u_kb (
        .clk(clk_100mhz), .rst_n(rst_n),
        .row(kb_row), .col(kb_col),
        .key_code(key_code), .key_valid(key_valid)
    );

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n)
            led <= 4'd0;
        else if (key_valid)
            led <= key_code;
    end

endmodule
