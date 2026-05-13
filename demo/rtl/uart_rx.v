// UART Receiver - 8N1, configurable baud rate
// Used for fingerprint sensor communication (default 57600 baud)
`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FREQ   = 50_000_000,  // 50MHz system clock
    parameter BAUD_RATE  = 57600        // default for fingerprint sensor
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx,
    output reg  [7:0]  rx_data,
    output reg         rx_valid
);

    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;
    localparam HALF_BIT   = BIT_PERIOD / 2;

    // States: IDLE, START, DATA, STOP
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] bit_cnt;      // counts clocks within a bit
    reg [2:0]  bit_idx;       // which bit are we receiving (0-7)

    // Edge detection on rx for sampling
    reg rx_d1, rx_d2;
    wire rx_negedge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end else begin
            rx_d1 <= rx;
            rx_d2 <= rx_d1;
        end
    end
    assign rx_negedge = rx_d2 && !rx_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            bit_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;  // pulse

            case (state)
                S_IDLE: begin
                    bit_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_negedge) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (bit_cnt == HALF_BIT) begin
                        // Sample mid-bit to verify start bit is zero
                        if (rx == 1'b0) begin
                            bit_cnt <= 16'd0;
                            state   <= S_DATA;
                        end else begin
                            state <= S_IDLE;  // false start, ignore
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end
                end

                S_DATA: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 16'd0;
                        rx_data[bit_idx] <= rx;
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end
                end

                S_STOP: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt  <= 16'd0;
                        rx_valid <= 1'b1;  // successfully received
                        state    <= S_IDLE;
                    end else begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
