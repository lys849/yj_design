// UART Transmitter — configurable baud rate & stop bits
// Default 8N1; STOP_BITS remains configurable for other UART devices.
`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200,
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
    localparam S_START = 2'd1;
    localparam S_DATA = 2'd2;
    localparam S_STOP = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg [1:0]  stop_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            stop_cnt  <= 2'd0;
            shift_reg <= 8'd0;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                S_IDLE: begin
                    tx <= 1'b1;
                    if (tx_start && !tx_busy) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= S_START;
                        clk_cnt   <= 16'd0;
                    end
                end

                S_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt <= 16'd0;
                        bit_idx <= 3'd0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    tx <= shift_reg[0];
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt   <= 16'd0;
                        shift_reg <= {1'b0, shift_reg[7:1]};
                        if (bit_idx == 3'd7) begin
                            state    <= S_STOP;
                            stop_cnt <= 2'd0;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt <= 16'd0;
                        if (stop_cnt == STOP_BITS - 1) begin
                            tx_busy <= 1'b0;
                            tx_done <= 1'b1;
                            state   <= S_IDLE;
                        end else begin
                            stop_cnt <= stop_cnt + 2'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
