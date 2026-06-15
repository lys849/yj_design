// UART Transmitter - configurable baud rate & stop bits (8N1 or 8N2)
`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 57600,
    parameter STOP_BITS = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    localparam S_IDLE = 2'd0;
    localparam S_DATA = 2'd1;
    localparam S_STOP = 2'd2;

    reg [1:0]  state;
    reg [15:0] bit_cnt;
    reg [3:0]  bit_idx;    // 0-7: data bits, 8: stop bit
    reg [7:0]  tx_data_r;  // latched tx_data at start
    reg [1:0]  stop_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            bit_cnt   <= 16'd0;
            bit_idx   <= 4'd0;
            stop_idx  <= 2'd0;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
            tx_data_r <= 8'd0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx       <= 1'b1;
                    tx_busy  <= 1'b0;
                    bit_cnt  <= 16'd0;
                    bit_idx  <= 4'd0;
                    stop_idx <= 2'd0;
                    if (tx_start) begin
                        state     <= S_DATA;
                        tx_busy   <= 1'b1;
                        tx        <= 1'b0;  // start bit
                        tx_data_r <= tx_data;
                    end
                end

                S_DATA: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 16'd0;
                        if (bit_idx == 4'd8) begin
                            state <= S_STOP;
                            tx    <= 1'b1;  // stop bit
                        end else begin
                            tx <= tx_data_r[bit_idx[2:0]];
                            bit_idx <= bit_idx + 4'd1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 16'd0;
                        if (stop_idx == STOP_BITS - 1) begin
                            state   <= S_IDLE;
                            tx_busy <= 1'b0;
                            tx_done <= 1'b1;
                        end else begin
                            stop_idx <= stop_idx + 2'd1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
