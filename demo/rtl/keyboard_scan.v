// 4x4 Matrix Keyboard Scanner with Debounce
// Two-phase scan: all-rows-low to detect column, then single-row to detect row
`timescale 1ns / 1ps

module keyboard_scan #(
    parameter DEBOUNCE_MS = 20,
    parameter CLK_FREQ    = 50_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] row,
    input  wire [3:0] col,
    output reg  [3:0] key_code,
    output reg        key_valid
);

    localparam DEBOUNCE_CNT = DEBOUNCE_MS * (CLK_FREQ / 1000);

    localparam PH_COL       = 2'd0;   // all rows low, detect column
    localparam PH_ROW       = 2'd1;   // one row at a time, detect row
    localparam PH_RELEASE   = 2'd2;   // wait for key release

    reg [1:0]  phase;
    reg [31:0] dcnt;          // debounce counter
    reg [3:0]  col_prev;      // previous col for debounce
    reg [1:0]  row_idx;       // row being checked in PH_ROW
    reg [1:0]  detected_col;  // column detected in PH_COL

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase    <= PH_COL;
            row      <= 4'b0000;   // all rows low for col detection
            dcnt     <= 32'd0;
            col_prev <= 4'hF;
            row_idx  <= 2'd0;
            key_code <= 4'd0;
            key_valid <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            case (phase)
                // ============================================
                // Phase 1: All rows LOW, debounce col
                // ============================================
                PH_COL: begin
                    row <= 4'b0000;

                    if (col != col_prev) begin
                        col_prev <= col;
                        dcnt     <= 32'd0;
                    end else if (dcnt == DEBOUNCE_CNT) begin
                        // Debounce complete
                        if (col != 4'hF) begin
                            // Key pressed: detect column
                            detected_col <=
                                col[0] == 1'b0 ? 2'd0 :
                                col[1] == 1'b0 ? 2'd1 :
                                col[2] == 1'b0 ? 2'd2 : 2'd3;
                            // Switch to row detection
                            row_idx <= 2'd0;
                            row     <= 4'b1110;
                            dcnt    <= 32'd0;
                            phase   <= PH_ROW;
                        end
                        // else: no key, continue debounce
                    end else begin
                        dcnt <= dcnt + 32'd1;
                    end
                end

                // ============================================
                // Phase 2: Scan one row at a time
                // ============================================
                PH_ROW: begin
                    // Check if current row has the pressed key
                    if (col[detected_col] == 1'b0) begin
                        // Found the row!
                        key_code  <= {row_idx, detected_col};
                        key_valid <= 1'b1;
                        row       <= 4'b0000;   // back to all-low for release detect
                        dcnt      <= 32'd0;
                        phase     <= PH_RELEASE;
                    end else begin
                        // Try next row
                        if (row_idx == 2'd3) begin
                            // Row not found (shouldn't happen if key released)
                            row   <= 4'b0000;
                            dcnt  <= 32'd0;
                            phase <= PH_COL;
                        end else begin
                            row_idx <= row_idx + 2'd1;
                            case (row_idx)
                                2'd0: row <= 4'b1101;
                                2'd1: row <= 4'b1011;
                                2'd2: row <= 4'b0111;
                                default: row <= 4'b1110;
                            endcase
                        end
                    end
                end

                // ============================================
                // Phase 3: Wait for key release
                // ============================================
                PH_RELEASE: begin
                    row <= 4'b0000;
                    if (col != col_prev) begin
                        col_prev <= col;
                        dcnt     <= 32'd0;
                    end else if (dcnt == DEBOUNCE_CNT) begin
                        if (col == 4'hF) begin
                            // Key released, scan again
                            phase <= PH_COL;
                            dcnt  <= 32'd0;
                        end
                        // else: key still held, keep waiting
                    end else begin
                        dcnt <= dcnt + 32'd1;
                    end
                end

                default: phase <= PH_COL;
            endcase
        end
    end

endmodule
