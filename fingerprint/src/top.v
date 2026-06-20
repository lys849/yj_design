//=============================================================================
// top.v — AS608 Fingerprint Recognition Demo (Nexys4 DDR, Pure Verilog)
//=============================================================================

module top (
    input  wire       sys_clk,
    input  wire       sys_resetn,

    // USB-UART (FTDI → PC terminal)
    output wire       uart_dbg_txd,
    input  wire       uart_dbg_rxd,

    // AS608 Fingerprint Sensor (PMOD JD)
    output wire       fp_sensor_tx,
    input  wire       fp_sensor_rx,

    // User LEDs
    output wire [3:0] led,

    // Push buttons
    input  wire [1:0] btn
);

    //=========================================================================
    // Internal wires
    //=========================================================================
    wire        dbg_tx_send;
    wire [7:0]  dbg_tx_data;
    wire        dbg_tx_busy;

    wire        fp_tx_send;
    wire [7:0]  fp_tx_data;
    wire        fp_tx_busy;

    wire [7:0]  fp_rx_data;
    wire        fp_rx_valid;

    //=========================================================================
    // Debug UART TX — 115200 bps (to PC terminal)
    //=========================================================================
    uart_tx #(
        .CLK_FREQ (100_000_000),
        .BAUD_RATE(115200)
    ) u_dbg_tx (
        .clk   (sys_clk),
        .rst_n (sys_resetn),
        .send  (dbg_tx_send),
        .data  (dbg_tx_data),
        .tx    (uart_dbg_txd),
        .busy  (dbg_tx_busy),
        .done  ()
    );

    //=========================================================================
    // Fingerprint UART TX — 57600 bps (to AS608)
    //=========================================================================
    uart_tx #(
        .CLK_FREQ (100_000_000),
        .BAUD_RATE(57600)
    ) u_fp_tx (
        .clk   (sys_clk),
        .rst_n (sys_resetn),
        .send  (fp_tx_send),
        .data  (fp_tx_data),
        .tx    (fp_sensor_tx),
        .busy  (fp_tx_busy),
        .done  ()
    );

    //=========================================================================
    // Fingerprint UART RX — 57600 bps (from AS608)
    //=========================================================================
    uart_rx #(
        .CLK_FREQ (100_000_000),
        .BAUD_RATE(57600)
    ) u_fp_rx (
        .clk   (sys_clk),
        .rst_n (sys_resetn),
        .rx    (fp_sensor_rx),
        .data  (fp_rx_data),
        .valid (fp_rx_valid)
    );

    //=========================================================================
    // AS608 Controller + Demo State Machine
    //=========================================================================
    as608_ctrl u_ctrl (
        .clk         (sys_clk),
        .rst_n       (sys_resetn),

        .fp_tx_data  (fp_tx_data),
        .fp_tx_send  (fp_tx_send),
        .fp_tx_busy  (fp_tx_busy),
        .fp_rx_data  (fp_rx_data),
        .fp_rx_valid (fp_rx_valid),

        .dbg_tx_data (dbg_tx_data),
        .dbg_tx_send (dbg_tx_send),
        .dbg_tx_busy (dbg_tx_busy),

        .led (led),
        .btn (btn)
    );

endmodule
