//=============================================================================
// uart_rx.v — Parameterized UART Receiver (simple counter-based)
//
// Algorithm:
//   1. Idle: wait for rx falling edge (start bit)
//   2. Wait HALF_PERIOD → sample start bit (should be 0)
//   3. Wait BIT_PERIOD  → sample each data bit (8x)
//   4. Wait BIT_PERIOD  → sample stop bit (should be 1)
//
// Parameters: CLK_FREQ, BAUD_RATE
//=============================================================================

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg [7:0]  data,
    output reg        valid
);

    localparam BIT_PERIOD  = CLK_FREQ / BAUD_RATE;
    localparam HALF_PERIOD = BIT_PERIOD / 2;

    // Synchronize async rx
    reg rx_s1, rx_s2;
    always @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
    end

    reg        busy;          // Receiving in progress
    reg [15:0] timer;         // Countdown to next sample point
    reg [3:0]  bit_idx;       // 0=start verify, 1-8=data, 9=stop
    reg [7:0]  shreg;         // Shift register for incoming data

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy    <= 1'b0;
            timer   <= 16'd0;
            bit_idx <= 4'd0;
            shreg   <= 8'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;  // default: pulsed low

            if (!busy) begin
                //---------------------------------------------------------
                // IDLE: wait for start bit (falling edge)
                //---------------------------------------------------------
                if (rx_s2 == 1'b0) begin
                    busy    <= 1'b1;
                    timer   <= HALF_PERIOD;  // First: wait to center
                    bit_idx <= 4'd0;
                end
            end else begin
                //---------------------------------------------------------
                // BUSY: count down to next sample point
                //---------------------------------------------------------
                if (timer > 16'd1) begin
                    timer <= timer - 16'd1;
                end else begin
                    // Sample point reached
                    case (bit_idx)
                        4'd0: begin  // Center of start bit
                            if (rx_s2 == 1'b0) begin
                                // Valid start → prepare for data bits
                                timer   <= BIT_PERIOD;
                                bit_idx <= 4'd1;
                            end else begin
                                // Glitch → abort
                                busy <= 1'b0;
                            end
                        end

                        4'd1, 4'd2, 4'd3, 4'd4,
                        4'd5, 4'd6, 4'd7, 4'd8: begin
                            // Sample data bit (LSB first)
                            shreg   <= {rx_s2, shreg[7:1]};
                            timer   <= BIT_PERIOD;
                            bit_idx <= bit_idx + 4'd1;
                        end

                        4'd9: begin  // Stop bit
                            if (rx_s2 == 1'b1) begin
                                data  <= shreg;
                                valid <= 1'b1;
                            end
                            // If stop bit is 0 (frame error), drop the byte
                            busy <= 1'b0;
                        end

                        default: begin
                            busy <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

endmodule
