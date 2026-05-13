// Fingerprint Sensor Controller (AS608-compatible protocol)
// Handles UART command/response communication with the sensor
// Protocol: Command packet -> Response/Acknowledge
`timescale 1ns / 1ps

module fingerprint_ctrl #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 57600
) (
    input  wire         clk,
    input  wire         rst_n,
    // Sensor UART interface
    output wire         sensor_tx,
    input  wire         sensor_rx,
    // Command interface (from C code via register)
    input  wire [7:0]   cmd_opcode,     // operation code
    input  wire [15:0]  cmd_param,      // parameter (e.g. buffer ID)
    input  wire         cmd_start,      // trigger command
    output reg  [15:0]  response,       // response data
    output reg  [7:0]   status,         // 0=idle, 1=busy, 2=done, 3=error
    output reg          cmd_done
);

    // Fingerprint sensor commands (AS608 protocol)
    localparam CMD_GET_IMAGE  = 8'h01;   // collect fingerprint image
    localparam CMD_GEN_CHAR   = 8'h02;   // generate feature from image
    localparam CMD_MATCH      = 8'h03;   // 1:1 match
    localparam CMD_SEARCH     = 8'h04;   // 1:N search in library
    localparam CMD_REG_MODEL  = 8'h05;   // combine features to template
    localparam CMD_STORE      = 8'h06;   // store template to library
    localparam CMD_DELETE     = 8'h0C;   // delete template
    localparam CMD_EMPTY      = 8'h0D;   // empty library
    localparam CMD_READ_PARAM = 8'h0F;   // read system parameters
    localparam CMD_ENROLL     = 8'h10;   // enroll (check duplicate)
    localparam CMD_DOWN_CHAR  = 8'h08;   // download feature
    localparam CMD_UP_CHAR    = 8'h09;   // upload feature

    // State machine
    localparam S_IDLE       = 4'd0;
    localparam S_SEND_CMD   = 4'd1;
    localparam S_WAIT_RESP  = 4'd2;
    localparam S_READ_RESP  = 4'd3;
    localparam S_DONE       = 4'd4;

    // UART internals
    reg  [7:0]  tx_data;
    reg         tx_start;
    wire        tx_busy;
    wire        tx_done;
    wire [7:0]  rx_data;
    wire        rx_valid;

    reg  [3:0]  state;
    reg  [3:0]  byte_idx;       // byte index in packet
    reg  [15:0] checksum;       // packet checksum
    reg  [6:0]  resp_bytes[0:11]; // response buffer (max 12 bytes)

    // Command packet structure (11 bytes):
    // [0]=0xEF01 (header), [2]=addr(4B), [6]=pkg_len(1B), [7]=cmd(1B),
    // [8]=P1(1B), [9]=P2(1B), [10]=checksum(2B)
    reg  [6:0]  pkg[0:10];      // 11-byte command package

    wire [7:0] pkg_ident  = 8'h01;  // Package identifier (default 1)
    wire [15:0] pkg_len   = 16'd3;  // cmd(1) + P1(1) + P2(1) = 3 bytes

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(sensor_tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(sensor_rx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    // Checksum computation
    wire [15:0] checksum_result = 16'd3 + {8'd0, cmd_opcode} + cmd_param;
    wire [6:0]  checksum_final  = checksum_result[6:0];

    // Response byte counter
    reg [3:0] rsp_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
            response <= 16'd0;
            status   <= 8'd0;
            cmd_done <= 1'b0;
            byte_idx <= 4'd0;
            checksum <= 16'd0;
            rsp_cnt  <= 4'd0;
        end else begin
            cmd_done <= 1'b0;
            tx_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    status  <= 8'd0;
                    rsp_cnt <= 4'd0;
                    if (cmd_start) begin
                        // Build command packet
                        pkg[0] <= 7'h5B;  // High byte of header (0xEF => top 7 bits for simplicity)
                        pkg[1] <= 7'h01;
                        pkg[2] <= 7'h01;  // Address (simplified)
                        pkg[3] <= 7'h01;
                        pkg[4] <= 7'h01;
                        pkg[5] <= 7'h01;
                        pkg[6] <= 7'd3;   // Length = 3
                        pkg[7] <= cmd_opcode[6:0];
                        pkg[8] <= cmd_param[14:8];
                        pkg[9] <= cmd_param[6:0];
                        // Checksum = sum of bytes[6:9]
                        checksum <= 16'd3 + {8'd0, cmd_opcode} + cmd_param;
                        pkg[10] <= checksum_final;

                        state    <= S_SEND_CMD;
                        byte_idx <= 4'd0;
                        status   <= 8'd1;  // busy
                    end
                end

                S_SEND_CMD: begin
                    if (!tx_busy) begin
                        if (byte_idx < 11) begin
                            tx_data  <= {1'b0, pkg[byte_idx]};
                            tx_start <= 1'b1;
                            byte_idx <= byte_idx + 4'd1;
                        end else begin
                            state    <= S_WAIT_RESP;
                            byte_idx <= 4'd0;
                        end
                    end
                end

                S_WAIT_RESP: begin
                    // After sending, wait for first response byte
                    if (rx_valid) begin
                        resp_bytes[rsp_cnt] <= rx_data[6:0];
                        rsp_cnt <= rsp_cnt + 4'd1;
                        state   <= S_READ_RESP;
                    end
                end

                S_READ_RESP: begin
                    if (rx_valid) begin
                        resp_bytes[rsp_cnt] <= rx_data[6:0];
                        rsp_cnt <= rsp_cnt + 4'd1;
                        // Response is 12 bytes, read until done
                        if (rsp_cnt >= 4'd11) begin
                            // Parse response: byte 7=confirm code, byte 8-9=parameter
                            response <= {1'b0, resp_bytes[8], 1'b0, resp_bytes[9]};
                            if (resp_bytes[7] == 7'd0) begin
                                status <= 8'd2;  // success
                            end else begin
                                status <= 8'd3;  // error
                            end
                            cmd_done <= 1'b1;
                            state    <= S_DONE;
                            rsp_cnt  <= 4'd0;
                        end
                    end
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
