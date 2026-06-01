// 4x4 Matrix Keyboard Scanner with Debounce
// Supports 16 keys: 0-9, A-F (function keys)
`timescale 1ns / 1ps

module keyboard_scan #(
    parameter DEBOUNCE_MS = 20,           // 20ms debounce
    parameter CLK_FREQ    = 50_000_000    // 50MHz
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] row,            // row outputs (scan lines)
    input  wire [3:0] col,            // column inputs
    output reg  [3:0] key_code,       // 0-15 key value
    output reg        key_valid       // key press detected pulse
);

    localparam DEBOUNCE_CNT = DEBOUNCE_MS * (CLK_FREQ / 1000);

    reg [1:0] scan_idx;              // which row being scanned
    reg [31:0] debounce_cnt;
    reg [3:0]  key_prev;
    reg [3:0]  key_curr;
    reg        stable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_idx     <= 2'd0;
            row          <= 4'b1110; // scan row 0 first
            debounce_cnt <= 32'd0;
            key_prev     <= 4'hF;    // no key pressed
            key_curr     <= 4'hF;
            key_valid    <= 1'b0;
            key_code     <= 4'd0;
            stable       <= 1'b0;
        end else begin
            key_valid <= 1'b0;  // pulse

            // Scan rows in sequence
            scan_idx <= (scan_idx == 2'd3) ? 2'd0 : scan_idx + 2'd1;

            case (scan_idx)
                2'd0: row <= 4'b1110;
                2'd1: row <= 4'b1101;
                2'd2: row <= 4'b1011;
                2'd3: row <= 4'b0111;
            endcase

            // Debounce logic
            if (col != key_curr) begin
                key_curr     <= col;
                debounce_cnt <= 32'd0;
                stable       <= 1'b0;
            end else if (debounce_cnt == DEBOUNCE_CNT) begin
                stable <= 1'b1;
            end else begin
                debounce_cnt <= debounce_cnt + 32'd1;
            end

            // When stable and a key is newly pressed
            if (stable && (col != 4'hF) && (key_prev != col)) begin
                key_code  <= {scan_idx,
                             col[0] == 1'b0 ? 2'd0 :
                             col[1] == 1'b0 ? 2'd1 :
                             col[2] == 1'b0 ? 2'd2 :
                             col[3] == 1'b0 ? 2'd3 : 2'd0};
                key_valid <= 1'b1;
            end

            key_prev <= col;
        end
    end

endmodule
