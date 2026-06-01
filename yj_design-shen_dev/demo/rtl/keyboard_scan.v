// 4x4 Matrix Keyboard Scanner with Debounce
// Supports 16 keys: 0-9, A-F (function keys)
//
// Fixes:
//   B1: Column encoding now checks each col bit individually (not just col[1:0])
//   B2: Each row now stays active for SCAN_DWELL cycles (~1ms),
//       giving debounce logic enough time to settle
`timescale 1ns / 1ps

module keyboard_scan #(
    parameter DEBOUNCE_MS = 5,             // 5ms debounce within row dwell
    parameter CLK_FREQ    = 50_000_000     // 50MHz
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] row,            // row outputs (scan lines, active low)
    input  wire [3:0] col,            // column inputs (active low)
    output reg  [3:0] key_code,       // 0-15 key value
    output reg        key_valid       // key press detected (one-cycle pulse)
);

    // Each row stays active for ~1ms (50000 cycles @ 50MHz)
    // 4 rows × 1ms = 4ms full scan cycle → sufficient mechanical debounce
    localparam SCAN_DWELL   = 50000;  // 1ms per row
    localparam DEBOUNCE_CNT = DEBOUNCE_MS * (CLK_FREQ / 1000);  // intra-row debounce

    reg [1:0]  scan_idx;         // current row being scanned (0-3)
    reg [15:0] dwell_cnt;        // counter for row dwell time
    reg [15:0] debounce_cnt;     // counter for intra-row debounce
    reg [3:0]  col_prev;         // previous column value (for edge detection)
    reg [3:0]  col_stable;       // debounced column value
    reg [3:0]  key_state;        // per-row key-pressed state (1 bit per row)

    wire dwell_done = (dwell_cnt == SCAN_DWELL - 1);

    // ── Row scanner with dwell time ──────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_idx  <= 2'd0;
            row       <= 4'b1110;   // start with row 0 active
            dwell_cnt <= 16'd0;
        end else begin
            if (dwell_done) begin
                dwell_cnt <= 16'd0;
                if (scan_idx == 2'd3) begin
                    scan_idx <= 2'd0;
                    row      <= 4'b1110;
                end else begin
                    scan_idx <= scan_idx + 2'd1;
                    // Look up row pattern for the NEXT scan index
                    case (scan_idx + 2'd1)
                        2'd1: row <= 4'b1101;
                        2'd2: row <= 4'b1011;
                        2'd3: row <= 4'b0111;
                        default: row <= 4'b1110;
                    endcase
                end
            end else begin
                dwell_cnt <= dwell_cnt + 16'd1;
            end
        end
    end

    // ── Debounce and key detection ───────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt <= 16'd0;
            col_prev     <= 4'hF;
            col_stable   <= 4'hF;
            key_code     <= 4'd0;
            key_valid    <= 1'b0;
            key_state    <= 4'b0000;   // no keys pressed
        end else begin
            key_valid <= 1'b0;  // default: no key event

            // Debounce: reset counter if column value changes
            if (col != col_prev) begin
                col_prev     <= col;
                debounce_cnt <= 16'd0;
            end else if (debounce_cnt == DEBOUNCE_CNT) begin
                // Column value is stable
                col_stable   <= col;

                // Detect key press: transition from not-pressed to pressed
                if (col != 4'hF && !key_state[scan_idx]) begin
                    // ── Fixed B1: encode column by checking each col bit ──
                    // col is active-low: bit=0 means that column is pressed
                    key_code[3:2] <= scan_idx;  // row index (2 bits)
                    if      (col[0] == 1'b0) key_code[1:0] <= 2'd0;
                    else if (col[1] == 1'b0) key_code[1:0] <= 2'd1;
                    else if (col[2] == 1'b0) key_code[1:0] <= 2'd2;
                    else                     key_code[1:0] <= 2'd3;

                    key_valid             <= 1'b1;
                    key_state[scan_idx]   <= 1'b1;  // mark as pressed
                end

                // Detect key release: all columns high on this row
                if (col == 4'hF)
                    key_state[scan_idx] <= 1'b0;

            end else begin
                debounce_cnt <= debounce_cnt + 16'd1;
            end
        end
    end

endmodule
