//=============================================================================
// uart_tx.v — Parameterized UART Transmitter
//
// 8 data bits, 1 stop bit, no parity.
// Send a byte by pulsing `send` high for one cycle while `data` is valid.
// `busy` is high while transmission is in progress.
// `done` pulses for one cycle when transmission completes.
//=============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,  // System clock frequency (Hz)
    parameter BAUD_RATE = 115200        // Baud rate (bps)
) (
    input  wire       clk,
    input  wire       rst_n,           // Active-low reset
    input  wire       send,            // Pulse: start sending
    input  wire [7:0] data,            // Byte to send
    output reg        tx,              // UART TX serial output
    output reg        busy,            // High during transmission
    output reg        done             // Pulses high for 1 cycle when done
);

    // Baud rate divider: CLK_FREQ / BAUD_RATE
    localparam BIT_PERIOD = CLK_FREQ / BAUD_RATE;

    reg [15:0] bit_cnt;       // Counts bit periods
    reg [3:0]  bit_idx;       // Which bit we're sending (0=start, 1-8=data, 9=stop)
    reg [8:0]  shift_reg;     // Shift register: start(0) + data(8) + stop(1)

    // State: 0=idle, 1=transmitting
    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;    // Line idle high
            busy      <= 1'b0;
            done      <= 1'b0;
            bit_cnt   <= 16'd0;
            bit_idx   <= 4'd0;
            shift_reg <= 9'd0;
            state     <= 1'b0;
        end else begin
            done <= 1'b0;  // Default: de-assert done pulse

            case (state)
                1'b0: begin  // IDLE
                    tx   <= 1'b1;  // Line idle
                    busy <= 1'b0;
                    if (send) begin
                        // Load shift register: start(0) + data[7:0] + stop(1)
                        shift_reg <= {1'b1, data[7:0], 1'b0};
                        bit_idx   <= 4'd0;
                        bit_cnt   <= 16'd0;
                        busy      <= 1'b1;
                        state     <= 1'b1;
                    end
                end

                1'b1: begin  // TRANSMITTING
                    busy <= 1'b1;
                    if (bit_cnt < BIT_PERIOD - 1) begin
                        bit_cnt <= bit_cnt + 16'd1;
                    end else begin
                        bit_cnt <= 16'd0;
                        tx      <= shift_reg[0];           // Output current bit
                        shift_reg <= {1'b0, shift_reg[8:1]}; // Shift right
                        bit_idx <= bit_idx + 4'd1;

                        if (bit_idx == 4'd9) begin  // Sent start + 8 data + stop = 10 bits
                            state <= 1'b0;
                            done  <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
