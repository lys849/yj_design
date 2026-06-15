// UART Board Test — echo loopback via board's FT2232 USB-UART
// PC sends byte → FPGA receives → FPGA sends back → PC sees echo
// LED[0] toggles on each received byte
`timescale 1ns / 1ps

module uart_test_top (
    input  wire clk_100mhz,
    input  wire rst_n,
    input  wire debug_rx,
    output wire debug_tx,
    output reg  [3:0] led
);

    wire [7:0] rx_data;
    wire       rx_valid;
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    uart_rx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_rx (
        .clk(clk_100mhz), .rst_n(rst_n),
        .rx(debug_rx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) u_tx (
        .clk(clk_100mhz), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(debug_tx), .tx_busy(tx_busy), .tx_done()
    );

    reg [7:0] rx_buf;
    reg       rx_pending;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            tx_data    <= 8'd0;
            tx_start   <= 1'b0;
            rx_pending <= 1'b0;
            rx_buf     <= 8'd0;
            led        <= 4'b0000;
        end else begin
            tx_start <= 1'b0;
            if (rx_valid) begin
                rx_buf     <= rx_data;
                rx_pending <= 1'b1;
                led[0]     <= ~led[0];
            end
            if (rx_pending && !tx_busy) begin
                tx_data    <= rx_buf;
                tx_start   <= 1'b1;
                rx_pending <= 1'b0;
            end
        end
    end

endmodule
