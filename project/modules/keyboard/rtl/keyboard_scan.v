// 4x4 Matrix Keyboard Scanner
// Row scan with µs-level dwell time, 2-FF col synchronizer, debounce
// key_code = row*4 + col (0-15), key_valid is single-cycle pulse
`timescale 1ns / 1ps

module keyboard_scan #(
    parameter CLK_FREQ    = 100_000_000,
    parameter DWELL_US    = 250,
    parameter DEBOUNCE_MS = 20
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] row,
    input  wire [3:0] col,
    output reg  [3:0] key_code,
    output reg        key_valid
);

    localparam DWELL_CNT    = CLK_FREQ / 1_000_000 * DWELL_US - 1;
    localparam DEBOUNCE_CNT = CLK_FREQ / 1_000 * DEBOUNCE_MS - 1;

    localparam S_SCAN     = 2'd0;
    localparam S_SAMPLE   = 2'd1;
    localparam S_DEBOUNCE = 2'd2;
    localparam S_RELEASE  = 2'd3;

    reg [1:0]  state;
    reg [1:0]  scan_row;
    reg [17:0] dwell_cnt;
    reg [23:0] dbnc_cnt;

    reg [3:0] col_d1, col_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_d1 <= 4'hF;
            col_d2 <= 4'hF;
        end else begin
            col_d1 <= col;
            col_d2 <= col_d1;
        end
    end

    reg [3:0] det_key;
    reg       det_valid;

    always @(*) begin
        det_valid = 1'b0;
        det_key   = 4'd0;
        if      (!col_d2[0]) begin det_valid = 1'b1; det_key = {scan_row, 2'd0}; end
        else if (!col_d2[1]) begin det_valid = 1'b1; det_key = {scan_row, 2'd1}; end
        else if (!col_d2[2]) begin det_valid = 1'b1; det_key = {scan_row, 2'd2}; end
        else if (!col_d2[3]) begin det_valid = 1'b1; det_key = {scan_row, 2'd3}; end
    end

    always @(*) begin
        case (scan_row)
            2'd0: row = 4'b1110;
            2'd1: row = 4'b1101;
            2'd2: row = 4'b1011;
            2'd3: row = 4'b0111;
        endcase
    end

    reg [3:0] pending_key;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_SCAN;
            scan_row    <= 2'd0;
            dwell_cnt   <= 18'd0;
            dbnc_cnt    <= 24'd0;
            key_code    <= 4'd0;
            key_valid   <= 1'b0;
            pending_key <= 4'd0;
        end else begin
            key_valid <= 1'b0;

            case (state)
                S_SCAN: begin
                    if (dwell_cnt == DWELL_CNT) begin
                        dwell_cnt <= 18'd0;
                        state     <= S_SAMPLE;
                    end else begin
                        dwell_cnt <= dwell_cnt + 18'd1;
                    end
                end

                S_SAMPLE: begin
                    if (det_valid) begin
                        pending_key <= det_key;
                        dbnc_cnt    <= 24'd0;
                        state       <= S_DEBOUNCE;
                    end else begin
                        scan_row <= scan_row + 2'd1;
                        state    <= S_SCAN;
                    end
                end

                S_DEBOUNCE: begin
                    if (!det_valid || det_key != pending_key) begin
                        scan_row <= scan_row + 2'd1;
                        state    <= S_SCAN;
                    end else if (dbnc_cnt == DEBOUNCE_CNT) begin
                        key_code  <= pending_key;
                        key_valid <= 1'b1;
                        state     <= S_RELEASE;
                    end else begin
                        dbnc_cnt <= dbnc_cnt + 24'd1;
                    end
                end

                S_RELEASE: begin
                    if (col_d2 == 4'hF) begin
                        scan_row <= scan_row + 2'd1;
                        state    <= S_SCAN;
                    end
                end

                default: state <= S_SCAN;
            endcase
        end
    end

endmodule
