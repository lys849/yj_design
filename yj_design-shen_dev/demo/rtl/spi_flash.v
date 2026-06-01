// SPI Flash Controller - for storing account data and fingerprint templates
// Implements SPI master mode 0 (CPOL=0, CPHA=0)
// Compatible with common SPI Flash (W25Qxx series)
//
// Fixes:
//   B6: wr_en now does WREN→PP (page program WITHOUT erase).
//       New erase_en input triggers WREN→ERASE→WAIT separately.
//       This prevents per-byte writes from erasing previously written data.
//       Added busy/done output to status bits for software polling.
`timescale 1ns / 1ps

module spi_flash #(
    parameter CLK_FREQ = 50_000_000,
    parameter SPI_CLK  = 5_000_000   // 5 MHz SPI clock
) (
    input  wire         clk,
    input  wire         rst_n,
    // SPI interface (to flash chip)
    output reg          spi_cs_n,
    output reg          spi_clk,
    output reg          spi_mosi,
    input  wire         spi_miso,
    // Command interface
    input  wire         wr_en,        // page program (no erase)
    input  wire         rd_en,        // read enable
    input  wire         erase_en,     // sector erase (new)
    input  wire [23:0]  addr,         // 24-bit flash address
    input  wire [7:0]   wr_data,
    output reg  [7:0]   rd_data,
    output reg          busy,
    output reg          done
);

    localparam SPI_DIV  = CLK_FREQ / SPI_CLK / 2;
    localparam CMD_READ  = 8'h03;   // Read Data Bytes
    localparam CMD_WREN  = 8'h06;   // Write Enable
    localparam CMD_PP    = 8'h02;   // Page Program
    localparam CMD_ERASE = 8'h20;   // Sector Erase (4KB)
    localparam CMD_RDSR  = 8'h05;   // Read Status Register

    // State machine
    localparam S_IDLE       = 4'd0;
    localparam S_WREN_PP    = 4'd1;  // send Write Enable (for page program)
    localparam S_PP         = 4'd2;  // Page Program: cmd + addr + data
    localparam S_WREN_ERASE = 4'd3;  // send Write Enable (for erase)
    localparam S_ERASE      = 4'd4;  // send Sector Erase + 24-bit address
    localparam S_WAIT_BUSY  = 4'd5;  // poll/wait after erase
    localparam S_READ       = 4'd6;
    localparam S_DONE       = 4'd7;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;       // bits shifted in current byte (0-7)
    reg [7:0]  shift_reg;     // shift register for TX/RX
    reg [15:0] clk_div;
    reg        spi_clk_en;
    reg        spi_clk_d;      // delayed spi_clk for edge detection
    reg [2:0]  byte_cnt;      // bytes sent in current command phase

    // SPI clock generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div    <= 16'd0;
            spi_clk    <= 1'b0;
            spi_clk_en <= 1'b0;
        end else begin
            if (clk_div == SPI_DIV - 1) begin
                clk_div <= 16'd0;
                if (spi_clk_en) begin
                    spi_clk <= ~spi_clk;
                end
            end else begin
                clk_div <= clk_div + 16'd1;
            end
        end
    end

    // SPI state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            spi_cs_n  <= 1'b1;
            spi_mosi  <= 1'b0;
            bit_cnt   <= 4'd0;
            byte_cnt  <= 3'd0;
            shift_reg <= 8'd0;
            rd_data   <= 8'd0;
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done      <= 1'b0;

            case (state)
                S_IDLE: begin
                    spi_cs_n  <= 1'b1;
                    spi_clk_en <= 1'b0;
                    busy      <= 1'b0;
                    bit_cnt   <= 4'd0;
                    byte_cnt  <= 3'd0;

                    // FIXED B6: erase is now a separate operation
                    if (erase_en) begin
                        busy  <= 1'b1;
                        state <= S_WREN_ERASE;
                    end else if (wr_en) begin
                        busy  <= 1'b1;
                        state <= S_WREN_PP;
                    end else if (rd_en) begin
                        busy  <= 1'b1;
                        state <= S_READ;
                    end
                end

                // ── Write Enable (for Page Program) ──────────
                S_WREN_PP: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    if (bit_cnt == 0 && !spi_clk_d)
                        shift_reg <= CMD_WREN;

                    if (spi_clk && !spi_clk_d) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt  <= 4'd0;
                        spi_cs_n <= 1'b1;
                        spi_clk_en <= 1'b0;
                        state <= S_PP;
                        byte_cnt <= 3'd0;
                    end
                end

                // ── Page Program (without prior erase) ───────
                S_PP: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;

                    // Load shift register at start of each byte
                    if (bit_cnt == 0 && !spi_clk_d) begin
                        case (byte_cnt)
                            3'd0: shift_reg <= CMD_PP;
                            3'd1: shift_reg <= addr[23:16];
                            3'd2: shift_reg <= addr[15:8];
                            3'd3: shift_reg <= addr[7:0];
                            3'd4: shift_reg <= wr_data;
                        endcase
                    end

                    if (spi_clk && !spi_clk_d && byte_cnt > 0) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end

                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt <= 4'd0;
                        if (byte_cnt == 4) begin
                            // All bytes sent (cmd + 3 addr + 1 data)
                            spi_cs_n  <= 1'b1;
                            spi_clk_en <= 1'b0;
                            state <= S_DONE;
                        end else begin
                            byte_cnt <= byte_cnt + 3'd1;
                        end
                    end
                end

                // ── Write Enable (for Erase) ────────────────
                S_WREN_ERASE: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    if (bit_cnt == 0 && !spi_clk_d)
                        shift_reg <= CMD_WREN;

                    if (spi_clk && !spi_clk_d) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt  <= 4'd0;
                        spi_cs_n <= 1'b1;
                        spi_clk_en <= 1'b0;
                        state <= S_ERASE;
                        byte_cnt <= 3'd0;
                    end
                end

                // ── Sector Erase (4KB) ──────────────────────
                S_ERASE: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;

                    if (bit_cnt == 0 && !spi_clk_d) begin
                        case (byte_cnt)
                            3'd0: shift_reg <= CMD_ERASE;
                            3'd1: shift_reg <= addr[23:16];
                            3'd2: shift_reg <= addr[15:8];
                            3'd3: shift_reg <= addr[7:0];
                        endcase
                    end

                    if (spi_clk && !spi_clk_d && byte_cnt > 0) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end

                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt <= 4'd0;
                        if (byte_cnt == 3) begin
                            // Erase command + 3 address bytes sent
                            spi_cs_n  <= 1'b1;
                            spi_clk_en <= 1'b0;
                            state <= S_WAIT_BUSY;
                            byte_cnt <= 3'd0;
                        end else begin
                            byte_cnt <= byte_cnt + 3'd1;
                        end
                    end
                end

                // ── Wait for erase to complete ──────────────
                S_WAIT_BUSY: begin
                    // Simplified: wait enough cycles for sector erase
                    // Real system would poll WIP bit via RDSR command
                    // Typical sector erase time: ~45ms
                    // For simulation/demo: skip long wait
                    state <= S_DONE;
                end

                // ── Read Data Bytes ─────────────────────────
                S_READ: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;

                    // Load shift register at start of each byte
                    if (bit_cnt == 0 && !spi_clk_d) begin
                        case (byte_cnt)
                            3'd0: shift_reg <= CMD_READ;
                            3'd1: shift_reg <= addr[23:16];
                            3'd2: shift_reg <= addr[15:8];
                            3'd3: shift_reg <= addr[7:0];
                        endcase
                    end

                    if (spi_clk && !spi_clk_d) begin
                        if (byte_cnt < 4) begin
                            // Sending command + address
                            spi_mosi <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt <= bit_cnt + 4'd1;
                            if (bit_cnt == 7) begin
                                bit_cnt <= 4'd0;
                                byte_cnt <= byte_cnt + 3'd1;
                            end
                        end else begin
                            // Receiving data byte
                            shift_reg <= {shift_reg[6:0], spi_miso};
                            bit_cnt <= bit_cnt + 4'd1;
                            if (bit_cnt == 7) begin
                                bit_cnt  <= 4'd0;
                                rd_data  <= {shift_reg[6:0], spi_miso};
                                spi_cs_n <= 1'b1;
                                spi_clk_en <= 1'b0;
                                state <= S_DONE;
                                byte_cnt <= 3'd0;
                            end
                        end
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Edge detection for SPI clock
    always @(posedge clk) spi_clk_d <= spi_clk;

endmodule
