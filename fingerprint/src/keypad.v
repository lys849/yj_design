//=============================================================================
// keypad.v — 4×4 Matrix Keypad Scanner with Debounce
//
// Scans by driving one row LOW at a time, reading columns.
// Pressed key = LOW on the column at the active row.
// Outputs stable key value after debounce (key held for ~20ms).
//
// Pinout (PMOD JB on Nexys4 DDR):
//   kb_row[3:0]  →  G14, P15, V11, V15  (FPGA outputs)
//   kb_col[3:0]  ←  K16, R16, T9, U11   (FPGA inputs)
//=============================================================================

module keypad (
    input  wire       clk,
    input  wire       rst_n,

    output reg  [3:0] kb_row,          // Row drive (one LOW at a time)
    input  wire [3:0] kb_col,          // Column read (LOW = pressed)

    output reg  [3:0] key_val,         // 0-15 = key hex value, stable
    output reg        key_valid        // Pulses 1 cycle when new key detected
);

    // Key map:
    //   Row 0, Col 0: '1' = 1   Row 0, Col 3: 'A' = 10
    //   Row 1, Col 0: '4' = 4   Row 1, Col 3: 'B' = 11
    //   Row 2, Col 0: '7' = 7   Row 2, Col 3: 'C' = 12
    //   Row 3, Col 0: '*' = 14  Row 3, Col 3: 'D' = 13
    //   (Col 1: 2,5,8,0; Col 2: 3,6,9,#=15)

    localparam SCAN_DIV = 100_000;     // 1kHz scan rate (100MHz / 100k)
    localparam DEBOUNCE = 20;          // 20 scan cycles = 20ms debounce

    reg [16:0] scan_cnt;
    reg [1:0]  scan_row;               // 0-3 current row being scanned
    reg [3:0]  col_sync;               // Synchronized column input
    reg [3:0]  prev_col;               // Previous stable column value
    reg [3:0]  stable_key;             // Debounced key code
    reg [7:0]  debounce_cnt;           // How many scans the key has been stable
    reg        key_pressed;            // Any key currently pressed

    // Column sync (2-stage for metastability)
    reg [3:0] col_s1;
    always @(posedge clk) begin
        col_s1   <= kb_col;
        col_sync <= col_s1;
    end

    // Scan counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 17'd0;
        end else begin
            if (scan_cnt >= SCAN_DIV - 1)
                scan_cnt <= 17'd0;
            else
                scan_cnt <= scan_cnt + 17'd1;
        end
    end

    wire scan_tick = (scan_cnt == SCAN_DIV - 1);

    // Row driver — one-hot-low
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_row <= 2'd0;
            kb_row   <= 4'b1110;  // Row 0 low
        end else if (scan_tick) begin
            scan_row <= scan_row + 2'd1;
            case (scan_row)
                2'd0: kb_row <= 4'b1110;
                2'd1: kb_row <= 4'b1101;
                2'd2: kb_row <= 4'b1011;
                2'd3: kb_row <= 4'b0111;
            endcase
        end
    end

    // Convert (row, col) to key value
    function [3:0] rowcol2key;
        input [1:0] r;
        input [1:0] c;
        begin
            case ({r, c})
                4'b00_00: rowcol2key = 4'd1;   // Row0 Col0 = '1'
                4'b00_01: rowcol2key = 4'd2;   // Row0 Col1 = '2'
                4'b00_10: rowcol2key = 4'd3;   // Row0 Col2 = '3'
                4'b00_11: rowcol2key = 4'd10;  // Row0 Col3 = 'A'
                4'b01_00: rowcol2key = 4'd4;   // Row1 Col0 = '4'
                4'b01_01: rowcol2key = 4'd5;   // Row1 Col1 = '5'
                4'b01_10: rowcol2key = 4'd6;   // Row1 Col2 = '6'
                4'b01_11: rowcol2key = 4'd11;  // Row1 Col3 = 'B'
                4'b10_00: rowcol2key = 4'd7;   // Row2 Col0 = '7'
                4'b10_01: rowcol2key = 4'd8;   // Row2 Col1 = '8'
                4'b10_10: rowcol2key = 4'd9;   // Row2 Col2 = '9'
                4'b10_11: rowcol2key = 4'd12;  // Row2 Col3 = 'C'
                4'b11_00: rowcol2key = 4'd14;  // Row3 Col0 = '*'
                4'b11_01: rowcol2key = 4'd0;   // Row3 Col1 = '0'
                4'b11_10: rowcol2key = 4'd15;  // Row3 Col2 = '#'
                4'b11_11: rowcol2key = 4'd13;  // Row3 Col3 = 'D'
            endcase
        end
    endfunction

    // Find which column is LOW (one-hot to binary)
    function [1:0] find_col;
        input [3:0] cols;
        begin
            if      (cols[0] == 1'b0) find_col = 2'd0;
            else if (cols[1] == 1'b0) find_col = 2'd1;
            else if (cols[2] == 1'b0) find_col = 2'd2;
            else                       find_col = 2'd3;
        end
    endfunction

    // Debounce and output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_col     <= 4'hF;
            stable_key   <= 4'd0;
            debounce_cnt <= 8'd0;
            key_pressed  <= 1'b0;
            key_val      <= 4'd0;
            key_valid    <= 1'b0;
        end else begin
            key_valid <= 1'b0;  // default: pulsed

            if (scan_tick) begin
                if (col_sync != 4'hF) begin
                    // ---- KEY DETECTED on this row ----
                    if (col_sync == prev_col && key_pressed) begin
                        if (debounce_cnt < DEBOUNCE) begin
                            debounce_cnt <= debounce_cnt + 8'd1;
                            if (debounce_cnt == DEBOUNCE - 1) begin
                                key_val   <= rowcol2key(scan_row, find_col(col_sync));
                                key_valid <= 1'b1;
                            end
                        end
                    end else begin
                        prev_col     <= col_sync;
                        key_pressed  <= 1'b1;
                        debounce_cnt <= 8'd0;
                        stable_key   <= rowcol2key(scan_row, find_col(col_sync));
                    end
                end else begin
                    // ---- NO KEY on this row: reset immediately ----
                    key_pressed  <= 1'b0;
                    debounce_cnt <= 8'd0;
                end
            end
        end
    end

endmodule
