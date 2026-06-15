// Fingerprint Sensor Controller (AS608 protocol per AS60x Communication Manual)
// Packet: Header(EF01) + Addr(4B) + PkgID(01) + Len(2B) + Instr + Params + Chksum(2B)
// Response: Header(EF01) + Addr(4B) + PkgID(07) + Len(2B) + Confirm + Params + Chksum(2B)
// UART: 57600 baud, 8N2
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
    output reg          cmd_done
);

    localparam S_IDLE      = 3'd0;
    localparam S_BUILD     = 3'd1;
    localparam S_SEND      = 3'd2;
    localparam S_WAIT_RESP = 3'd3;
    localparam S_READ_RESP = 3'd4;
    localparam S_PARSE     = 3'd5;
    localparam S_DONE      = 3'd6;

    reg  [7:0]  tx_data;
    reg         tx_start;
    wire        tx_busy, tx_done_w;
    wire [7:0]  rx_data;
    wire        rx_valid;

    uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .STOP_BITS(2)) u_tx (
        .clk(clk), .rst_n(rst_n),
        .tx_data(tx_data), .tx_start(tx_start),
        .tx(sensor_tx), .tx_busy(tx_busy), .tx_done(tx_done_w)
    );

    uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .STOP_BITS(2)) u_rx (
        .clk(clk), .rst_n(rst_n),
        .rx(sensor_rx), .rx_data(rx_data), .rx_valid(rx_valid)
    );

    reg [7:0]  pkt [0:16];
    reg [4:0]  pkt_len;
    reg [4:0]  byte_idx;

    reg [7:0]  resp_buf [0:31];
    reg [5:0]  rsp_cnt;
    reg [5:0]  resp_total;

    reg [2:0]  state;
    reg [23:0] timeout_cnt;
    localparam TIMEOUT_MAX = CLK_FREQ / 5; // 200ms

    reg [7:0]  cur_opcode;
    reg [15:0] cur_param;
    reg [15:0] chksum;
    reg [4:0]  param_end;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            tx_start    <= 1'b0;
            tx_data     <= 8'd0;
            response    <= 16'd0;
            status      <= 8'd0;
            cmd_done    <= 1'b0;
            byte_idx    <= 5'd0;
            pkt_len     <= 5'd0;
            rsp_cnt     <= 6'd0;
            resp_total  <= 6'd0;
            timeout_cnt <= 24'd0;
            cur_opcode  <= 8'd0;
            cur_param   <= 16'd0;
            chksum      <= 16'd0;
            param_end   <= 5'd0;
        end else begin
            cmd_done <= 1'b0;
            tx_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    status      <= 8'd0;
                    rsp_cnt     <= 6'd0;
                    resp_total  <= 6'd0;
                    timeout_cnt <= 24'd0;
                    if (cmd_start) begin
                        cur_opcode <= cmd_opcode;
                        cur_param  <= cmd_param;
                        status     <= 8'd1;
                        state      <= S_BUILD;
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
                        end else begin
                            state       <= S_WAIT_RESP;
                            rsp_cnt     <= 6'd0;
                            resp_total  <= 6'd0;
                            timeout_cnt <= 24'd0;
                        end
                    end
                end

                S_WAIT_RESP: begin
                    timeout_cnt <= timeout_cnt + 24'd1;
                    if (rx_valid) begin
                        resp_buf[0] <= rx_data;
                        rsp_cnt     <= 6'd1;
                        state       <= S_READ_RESP;
                        timeout_cnt <= 24'd0;
                    end else if (timeout_cnt >= TIMEOUT_MAX) begin
                        status   <= 8'd3;
                        cmd_done <= 1'b1;
                        state    <= S_DONE;
                    end
                end

                S_READ_RESP: begin
                    timeout_cnt <= timeout_cnt + 24'd1;
                    if (rx_valid) begin
                        if (rsp_cnt < 6'd32)
                            resp_buf[rsp_cnt] <= rx_data;
                        rsp_cnt     <= rsp_cnt + 6'd1;
                        timeout_cnt <= 24'd0;

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

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
