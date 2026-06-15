// UART Receiver — configurable baud rate & stop bits
// Mid-bit sampling with false-start rejection
// All external inputs go through 2-FF synchronizer
`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter STOP_BITS = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT   = BIT_PERIOD / 2;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [1:0]  stop_cnt;

    reg rx_d1, rx_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end else begin
            rx_d1 <= rx;
            rx_d2 <= rx_d1;
        end
    end

    wire rx_falling = rx_d2 & ~rx_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            stop_cnt <= 2'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    if (rx_falling) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (clk_cnt == HALF_BIT) begin
                        clk_cnt <= 16'd0;
                        if (rx_d2 == 1'b0) begin
                            state   <= S_DATA;
                            bit_idx <= 3'd0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt          <= 16'd0;
                        rx_data[bit_idx] <= rx_d2;
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
                    if (clk_cnt == BIT_PERIOD - 1) begin
                        clk_cnt <= 16'd0;
                        if (stop_cnt == STOP_BITS - 1) begin
                            rx_valid <= 1'b1;
                            state    <= S_IDLE;
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
