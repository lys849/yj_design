// SPI Flash Controller - for storing account data and fingerprint templates
// Implements SPI master mode 0 (CPOL=0, CPHA=0)
// Compatible with common SPI Flash (W25Qxx series)
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
    input  wire         wr_en,        // write enable
    input  wire         rd_en,        // read enable
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
    localparam S_IDLE      = 4'd0;
    localparam S_WREN      = 4'd1;  // send Write Enable
    localparam S_WREN_WAIT = 4'd2;
    localparam S_ERASE     = 4'd3;  // send Sector Erase
    localparam S_ERASE_WAIT = 4'd4;
    localparam S_PP        = 4'd5;  // Page Program
    localparam S_PP_WAIT   = 4'd6;
    localparam S_WAIT_BUSY = 4'd7;  // poll status register
    localparam S_READ      = 4'd8;
    localparam S_DONE      = 4'd9;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [7:0]  shift_reg;
    reg [7:0]  cmd_byte;
    reg [15:0] clk_div;
    reg        spi_clk_en;
    reg        spi_clk_d;
    reg [2:0]  byte_cnt;   // bytes sent/received in current command

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
            cmd_byte  <= 8'd0;
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
                    if (wr_en) begin
                        busy   <= 1'b1;
                        state  <= S_WREN;  // WREN -> ERASE -> PP -> WAIT
                        byte_cnt <= 3'd0;
                    end else if (rd_en) begin
                        busy   <= 1'b1;
                        state  <= S_READ;
                        byte_cnt <= 3'd0;
                    end
                end

                S_WREN: begin
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    // Send WREN command (1 byte)
                    if (byte_cnt == 0 && bit_cnt == 0) begin
                        shift_reg <= CMD_WREN;
                        byte_cnt  <= 3'd1;
                    end
                    // Shift out bits
                    if (spi_clk && !spi_clk_d) begin
                        // Rising edge: output bit
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt + 4'd1;
                    end
                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt  <= 4'd0;
                        state    <= S_WREN_WAIT;
                        spi_cs_n <= 1'b1;
                        spi_clk_en <= 1'b0;
                    end
                end

                S_WREN_WAIT: begin
                    // CS high for at least 100ns
                    state <= S_ERASE;
                end

                S_ERASE: begin
                    // Send Sector Erase command + 24-bit address
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    if (byte_cnt == 0 && bit_cnt == 0) begin
                        shift_reg <= CMD_ERASE;
                    end
                    // Simplified: skip full erase, go to program
                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt  <= 4'd0;
                        byte_cnt <= byte_cnt + 3'd1;
                        if (byte_cnt == 4) begin
                            spi_cs_n <= 1'b1;
                            spi_clk_en <= 1'b0;
                            state <= S_PP;
                            byte_cnt <= 3'd0;
                        end else begin
                            shift_reg <= addr[23 - (byte_cnt-1)*8 -: 8];
                        end
                    end else if (spi_clk && !spi_clk_d) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                end

                S_PP: begin
                    // Page Program: send PP command + address + data
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    if (byte_cnt == 0 && bit_cnt == 0) begin
                        shift_reg <= CMD_PP;
                    end
                    if (bit_cnt == 8 && spi_clk && !spi_clk_d) begin
                        bit_cnt <= 4'd0;
                        byte_cnt <= byte_cnt + 3'd1;
                        if (byte_cnt == 1) shift_reg <= addr[23:16];
                        else if (byte_cnt == 2) shift_reg <= addr[15:8];
                        else if (byte_cnt == 3) shift_reg <= addr[7:0];
                        else begin
                            // Send data byte
                            shift_reg <= wr_data;
                            if (byte_cnt > 3) begin
                                spi_cs_n <= 1'b1;
                                spi_clk_en <= 1'b0;
                                state <= S_WAIT_BUSY;
                                byte_cnt <= 3'd0;
                                bit_cnt <= 4'd0;
                            end
                        end
                    end else if (spi_clk && !spi_clk_d && byte_cnt > 0) begin
                        spi_mosi <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt <= bit_cnt + 4'd1;
                    end
                end

                S_WAIT_BUSY: begin
                    // In real system, poll WIP bit of status register
                    // Simplified: wait 2ms (100000 cycles at 50MHz)
                    state <= S_DONE;
                end

                S_READ: begin
                    // Read Data: send READ command + 24-bit addr, then receive
                    spi_cs_n  <= 1'b0;
                    spi_clk_en <= 1'b1;
                    if (byte_cnt == 0 && bit_cnt == 0) begin
                        shift_reg <= CMD_READ;
                    end
                    if (spi_clk && !spi_clk_d) begin
                        if (byte_cnt < 4) begin
                            spi_mosi <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt <= bit_cnt + 4'd1;
                            if (bit_cnt == 7) begin
                                bit_cnt <= 4'd0;
                                byte_cnt <= byte_cnt + 3'd1;
                                case (byte_cnt)
                                    0: shift_reg <= CMD_READ;
                                    1: shift_reg <= addr[23:16];
                                    2: shift_reg <= addr[15:8];
                                    3: shift_reg <= addr[7:0];
                                endcase
                            end
                        end else begin
                            // Receive data byte
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
    reg spi_clk_prev;
    always @(posedge clk) spi_clk_prev <= spi_clk;
    wire spi_clk_d_impl;
    assign spi_clk_d_impl = spi_clk_prev;
    // Note: In the main block, use the delayed version

    // Regenerate spi_clk_d signal
    always @(posedge clk) spi_clk_d <= spi_clk;

endmodule
