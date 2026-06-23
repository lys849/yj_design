// Fingerprint Sensor Controller (AS608 protocol per AS60x Communication Manual)
// Packet: Header(EF01) + Addr(4B) + PkgID(01) + Len(2B) + Instr + Params + Chksum(2B)
// Response: Header(EF01) + Addr(4B) + PkgID(07) + Len(2B) + Confirm + Params + Chksum(2B)
// UART: 57600 baud, 8N1 by default.
// Note: AS60x documentation lists 8N2, but the collaborator's Nexys4 DDR
// AS608 demo communicates successfully with 8N1. If a different sensor batch
// times out, change both STOP_BITS parameters below to 2 for an A/B check.
// Init sequence mirrors the verified board test: wait 3s, send wake byte 0x55,
// wait 1s, then send the first command packet.
// TX inter-byte gap: 2ms (required for reliable AS608 communication)
`timescale 1ns / 1ps

module fingerprint_ctrl #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 57600
) (
    input  wire         clk,
    input  wire         rst_n,
    output wire         sensor_tx,
    input  wire         sensor_rx,
    input  wire [7:0]   cmd_opcode,
    input  wire [15:0]  cmd_param,
    input  wire         cmd_start,
    output reg  [15:0]  response,
    output reg  [7:0]   status,         // 0=idle, 1=busy, 2=done, 3=error
    output reg          cmd_done,
    output wire [31:0]  debug_info
);

    localparam S_BOOT_WAIT    = 4'd0;
    localparam S_IDLE         = 4'd1;
    localparam S_WAKE_SEND    = 4'd2;
    localparam S_WAKE_WAIT_TX = 4'd3;
    localparam S_WAKE_GUARD   = 4'd4;
    localparam S_BUILD        = 4'd5;
    localparam S_SEND         = 4'd6;
    localparam S_WAIT_TX_DONE = 4'd7;
    localparam S_BYTE_GAP     = 4'd8;
    localparam S_WAIT_RESP    = 4'd9;
    localparam S_READ_RESP    = 4'd10;
    localparam S_PARSE        = 4'd11;
    localparam S_DONE         = 4'd12;

    localparam [31:0] BOOT_DELAY  = CLK_FREQ * 3;      // 3 seconds
    localparam [31:0] WAKE_DELAY  = CLK_FREQ;          // 1 second
    localparam [31:0] TIMEOUT_MAX = CLK_FREQ * 8;      // 8 seconds
    localparam [17:0] BYTE_GAP    = CLK_FREQ / 500;    // 2ms

    reg  [7:0]  tx_data;
    reg         tx_start;
    wire        tx_busy, tx_done_w;
    wire [7:0]  rx_data;
    wire        rx_valid;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .STOP_BITS(1)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(sensor_tx), .tx_busy(tx_busy), .tx_done(tx_done_w)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .STOP_BITS(1)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(sensor_rx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    reg [7:0]  pkt [0:16];
    reg [4:0]  pkt_len;
    reg [4:0]  byte_idx;

    reg [7:0]  resp_buf [0:31];
    reg [5:0]  rsp_cnt;
    reg [5:0]  resp_total;

    reg [3:0]  state;
    reg [31:0] timeout_cnt;
    reg [17:0] gap_cnt;
    reg [31:0] init_cnt;

    reg [7:0]  cur_opcode;
    reg [15:0] cur_param;
    reg [15:0] chksum;
    reg [4:0]  param_end;
    reg        rx_seen;
    reg [7:0]  last_rx_data;
    reg        wake_done;
    reg        pending_cmd;
    reg [2:0]  debug_state;

    always @(*) begin
        case (state)
            S_IDLE:         debug_state = 3'd0;
            S_BOOT_WAIT:    debug_state = 3'd1;
            S_WAKE_SEND,
            S_WAKE_WAIT_TX,
            S_WAKE_GUARD:   debug_state = 3'd2;
            S_BUILD:        debug_state = 3'd3;
            S_SEND,
            S_WAIT_TX_DONE,
            S_BYTE_GAP:     debug_state = 3'd4;
            S_WAIT_RESP:    debug_state = 3'd5;
            S_READ_RESP,
            S_PARSE:        debug_state = 3'd6;
            S_DONE:         debug_state = 3'd7;
            default:        debug_state = 3'd0;
        endcase
    end

    assign debug_info = {4'd0, rx_seen, debug_state, byte_idx, rsp_cnt, pkt_len, last_rx_data};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_BOOT_WAIT;
            tx_start    <= 1'b0;
            tx_data     <= 8'd0;
            response    <= 16'd0;
            status      <= 8'd0;
            cmd_done    <= 1'b0;
            byte_idx    <= 5'd0;
            pkt_len     <= 5'd0;
            rsp_cnt     <= 6'd0;
            resp_total  <= 6'd0;
            timeout_cnt <= 32'd0;
            gap_cnt     <= 18'd0;
            init_cnt    <= 32'd0;
            cur_opcode  <= 8'd0;
            cur_param   <= 16'd0;
            chksum      <= 16'd0;
            param_end   <= 5'd0;
            rx_seen     <= 1'b0;
            last_rx_data <= 8'd0;
            wake_done   <= 1'b0;
            pending_cmd <= 1'b0;
        end else begin
            cmd_done <= 1'b0;
            tx_start <= 1'b0;

            case (state)
                S_BOOT_WAIT: begin
                    status <= pending_cmd ? 8'd1 : 8'd0;
                    if (cmd_start) begin
                        cur_opcode <= cmd_opcode;
                        cur_param  <= cmd_param;
                        status     <= 8'd1;
                        rx_seen    <= 1'b0;
                        last_rx_data <= 8'd0;
                        rsp_cnt    <= 6'd0;
                        resp_total <= 6'd0;
                        byte_idx   <= 5'd0;
                        pkt_len    <= 5'd0;
                        pending_cmd <= 1'b1;
                    end
                    if (init_cnt >= BOOT_DELAY) begin
                        init_cnt <= 32'd0;
                        if (pending_cmd || cmd_start) begin
                            pending_cmd <= 1'b0;
                            if (wake_done)
                                state <= S_BUILD;
                            else
                                state <= S_WAKE_SEND;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        init_cnt <= init_cnt + 32'd1;
                    end
                end

                S_IDLE: begin
                    timeout_cnt <= 32'd0;
                    if (cmd_start) begin
                        cur_opcode <= cmd_opcode;
                        cur_param  <= cmd_param;
                        status     <= 8'd1;
                        rx_seen    <= 1'b0;
                        last_rx_data <= 8'd0;
                        rsp_cnt    <= 6'd0;
                        resp_total <= 6'd0;
                        byte_idx   <= 5'd0;
                        pkt_len    <= 5'd0;
                        if (wake_done)
                            state <= S_BUILD;
                        else
                            state <= S_WAKE_SEND;
                    end
                end

                S_WAKE_SEND: begin
                    if (!tx_busy) begin
                        tx_data  <= 8'h55;
                        tx_start <= 1'b1;
                        state    <= S_WAKE_WAIT_TX;
                    end
                end

                S_WAKE_WAIT_TX: begin
                    if (tx_done_w) begin
                        wake_done <= 1'b1;
                        init_cnt  <= 32'd0;
                        state     <= S_WAKE_GUARD;
                    end
                end

                S_WAKE_GUARD: begin
                    if (init_cnt >= WAKE_DELAY) begin
                        init_cnt <= 32'd0;
                        state    <= S_BUILD;
                    end else begin
                        init_cnt <= init_cnt + 32'd1;
                    end
                end

                S_BUILD: begin
                    pkt[0] <= 8'hEF;
                    pkt[1] <= 8'h01;
                    pkt[2] <= 8'hFF;
                    pkt[3] <= 8'hFF;
                    pkt[4] <= 8'hFF;
                    pkt[5] <= 8'hFF;
                    pkt[6] <= 8'h01;

                    case (cur_opcode)
                        8'h02: begin // GenChar: BufferID
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h04;
                            pkt[9]  <= cur_opcode;
                            pkt[10] <= cur_param[7:0];
                            chksum  <= 16'h01 + 16'h0004 + {8'd0, cur_opcode} + {8'd0, cur_param[7:0]};
                            param_end <= 5'd11;
                            pkt_len <= 5'd13;
                        end
                        8'h04: begin // Search: BufferID + StartPage + PageNum
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h08;
                            pkt[9]  <= cur_opcode;
                            pkt[10] <= cur_param[15:8];
                            pkt[11] <= 8'h00;
                            pkt[12] <= 8'h00;
                            pkt[13] <= 8'h00;
                            pkt[14] <= cur_param[7:0];
                            chksum  <= 16'h01 + 16'h0008 + {8'd0, cur_opcode}
                                     + {8'd0, cur_param[15:8]}
                                     + {8'd0, cur_param[7:0]};
                            param_end <= 5'd15;
                            pkt_len <= 5'd17;
                        end
                        8'h06, 8'h07: begin // StoreChar/LoadChar: BufferID + PageID
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h06;
                            pkt[9]  <= cur_opcode;
                            pkt[10] <= cur_param[15:8];
                            pkt[11] <= 8'h00;
                            pkt[12] <= cur_param[7:0];
                            chksum  <= 16'h01 + 16'h0006 + {8'd0, cur_opcode}
                                     + {8'd0, cur_param[15:8]}
                                     + {8'd0, cur_param[7:0]};
                            param_end <= 5'd13;
                            pkt_len <= 5'd15;
                        end
                        8'h0C: begin // DeletChar: PageID + Count=1
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h07;
                            pkt[9]  <= cur_opcode;
                            pkt[10] <= cur_param[15:8];
                            pkt[11] <= cur_param[7:0];
                            pkt[12] <= 8'h00;
                            pkt[13] <= 8'h01;
                            chksum  <= 16'h01 + 16'h0007 + {8'd0, cur_opcode}
                                     + {8'd0, cur_param[15:8]}
                                     + {8'd0, cur_param[7:0]}
                                     + 16'h0001;
                            param_end <= 5'd14;
                            pkt_len <= 5'd16;
                        end
                        8'h13: begin // VfyPwd: 4-byte password
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h07;
                            pkt[9]  <= 8'h13;
                            pkt[10] <= cur_param[15:8];
                            pkt[11] <= cur_param[7:0];
                            pkt[12] <= 8'h00;
                            pkt[13] <= 8'h00;
                            chksum  <= 16'h01 + 16'h0007 + 16'h0013
                                     + {8'd0, cur_param[15:8]}
                                     + {8'd0, cur_param[7:0]};
                            param_end <= 5'd14;
                            pkt_len <= 5'd16;
                        end
                        default: begin // Simple commands: GetImage, Match, RegModel, Empty, Enroll, Identify, etc.
                            pkt[7]  <= 8'h00; pkt[8]  <= 8'h03;
                            pkt[9]  <= cur_opcode;
                            chksum  <= 16'h01 + 16'h0003 + {8'd0, cur_opcode};
                            param_end <= 5'd10;
                            pkt_len <= 5'd12;
                        end
                    endcase

                    byte_idx <= 5'd0;
                    state    <= S_SEND;
                end

                S_SEND: begin
                    if (!tx_busy) begin
                        if (byte_idx < pkt_len) begin
                            if (byte_idx == param_end)
                                tx_data <= chksum[15:8];
                            else if (byte_idx == param_end + 5'd1)
                                tx_data <= chksum[7:0];
                            else
                                tx_data <= pkt[byte_idx];
                            tx_start <= 1'b1;
                            byte_idx <= byte_idx + 5'd1;
                            gap_cnt  <= 18'd0;
                            state    <= S_WAIT_TX_DONE;
                        end else begin
                            state       <= S_WAIT_RESP;
                            rsp_cnt     <= 6'd0;
                            resp_total  <= 6'd0;
                            timeout_cnt <= 32'd0;
                        end
                    end
                end

                S_WAIT_TX_DONE: begin
                    if (tx_done_w) begin
                        gap_cnt <= 18'd0;
                        state   <= S_BYTE_GAP;
                    end
                end

                S_BYTE_GAP: begin
                    if (gap_cnt >= BYTE_GAP) begin
                        gap_cnt <= 18'd0;
                        state   <= S_SEND;
                    end else begin
                        gap_cnt <= gap_cnt + 18'd1;
                    end
                end

                S_WAIT_RESP: begin
                    timeout_cnt <= timeout_cnt + 32'd1;
                    if (rx_valid) begin
                        resp_buf[0] <= rx_data;
                        rx_seen     <= 1'b1;
                        last_rx_data <= rx_data;
                        rsp_cnt     <= 6'd1;
                        state       <= S_READ_RESP;
                        timeout_cnt <= 32'd0;
                    end else if (timeout_cnt >= TIMEOUT_MAX) begin
                        status   <= 8'd3;
                        cmd_done <= 1'b1;
                        state    <= S_DONE;
                    end
                end

                S_READ_RESP: begin
                    timeout_cnt <= timeout_cnt + 32'd1;
                    if (rx_valid) begin
                        rx_seen <= 1'b1;
                        last_rx_data <= rx_data;
                        if (rsp_cnt < 6'd32)
                            resp_buf[rsp_cnt] <= rx_data;
                        rsp_cnt     <= rsp_cnt + 6'd1;
                        timeout_cnt <= 32'd0;

                        if (rsp_cnt == 6'd8)
                            resp_total <= 6'd9 + {1'b0, rx_data[4:0]};

                        if (resp_total != 6'd0 && (rsp_cnt + 6'd1) >= resp_total)
                            state <= S_PARSE;
                    end else if (timeout_cnt >= TIMEOUT_MAX) begin
                        if (rsp_cnt >= 6'd10)
                            state <= S_PARSE;
                        else begin
                            status   <= 8'd3;
                            cmd_done <= 1'b1;
                            state    <= S_DONE;
                        end
                    end
                end

                S_PARSE: begin
                    if (resp_buf[9] == 8'h00) begin
                        status   <= 8'd2;
                        response <= {resp_buf[10], resp_buf[11]};
                    end else begin
                        status   <= 8'd3;
                        response <= {8'd0, resp_buf[9]};
                    end
                    cmd_done <= 1'b1;
                    state    <= S_DONE;
                end

                S_DONE: begin
                    state <= S_IDLE;
                end

                default: state <= S_BOOT_WAIT;
            endcase
        end
    end

endmodule
