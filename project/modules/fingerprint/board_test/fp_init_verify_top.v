// AS608 init verification board test.
// Mirrors the collaborator's known-good init flow:
// wait 3s -> send wake byte 0x55 -> wait 1s ->
// VfyPwd -> ReadSysPara -> ValidTmplNum.
`timescale 1ns / 1ps

module fp_init_verify_top (
    input  wire       clk_100mhz,
    input  wire       rst_n,

    output wire       uart_dbg_tx,
    input  wire       uart_dbg_rx,

    output wire       fp_sensor_tx,
    input  wire       fp_sensor_rx,

    output reg  [3:0] led
);

    localparam [31:0] BOOT_DELAY = 32'd300_000_000;  // 3s
    localparam [31:0] WAKE_DELAY = 32'd100_000_000;  // 1s
    localparam [31:0] BYTE_GAP   = 32'd200_000;      // 2ms
    localparam [31:0] RX_TIMEOUT = 32'd800_000_000;  // 8s

    localparam CMD_VFYPWD   = 2'd0;
    localparam CMD_READSYS  = 2'd1;
    localparam CMD_VALIDNUM = 2'd2;

    localparam MSG_BANNER   = 4'd0;
    localparam MSG_WAKE     = 4'd1;
    localparam MSG_VFYPWD   = 4'd2;
    localparam MSG_READSYS  = 4'd3;
    localparam MSG_VALIDNUM = 4'd4;
    localparam MSG_ACK      = 4'd5;
    localparam MSG_CNT      = 4'd6;
    localparam MSG_LAST     = 4'd7;
    localparam MSG_CRLF     = 4'd8;
    localparam MSG_TIMEOUT  = 4'd9;
    localparam MSG_OK       = 4'd10;

    localparam S_BOOT_WAIT      = 8'd0;
    localparam S_WAKE_SEND      = 8'd1;
    localparam S_WAKE_WAIT      = 8'd2;
    localparam S_CMD_PREP       = 8'd3;
    localparam S_CMD_SEND       = 8'd4;
    localparam S_CMD_GAP        = 8'd5;
    localparam S_RECV           = 8'd6;
    localparam S_RESULT_ACK_MSG = 8'd7;
    localparam S_RESULT_ACK_H   = 8'd8;
    localparam S_RESULT_ACK_L   = 8'd9;
    localparam S_RESULT_CNT_MSG = 8'd10;
    localparam S_RESULT_CNT_H   = 8'd11;
    localparam S_RESULT_CNT_L   = 8'd12;
    localparam S_RESULT_LAST_MSG= 8'd13;
    localparam S_RESULT_LAST_H  = 8'd14;
    localparam S_RESULT_LAST_L  = 8'd15;
    localparam S_RESULT_CRLF    = 8'd16;
    localparam S_NEXT_CMD       = 8'd17;
    localparam S_DONE           = 8'd18;
    localparam S_PRINT_CHAR     = 8'd40;

    reg [7:0] state;
    reg [7:0] return_state;
    reg [31:0] timer;

    reg [1:0] cmd_id;
    reg [4:0] cmd_len;
    reg [4:0] cmd_idx;
    reg [7:0] cmd_buf [0:15];

    reg [7:0] rsp_buf [0:31];
    reg [5:0] rsp_idx;
    reg [5:0] rsp_total;
    reg [7:0] rsp_ack;
    reg [7:0] rsp_count;
    reg [7:0] last_rx;

    reg [7:0] fp_tx_data;
    reg       fp_tx_start;
    wire      fp_tx_busy;
    wire [7:0] fp_rx_data;
    wire       fp_rx_valid;

    reg [7:0] dbg_tx_data;
    reg       dbg_tx_start;
    wire      dbg_tx_busy;

    reg [3:0] msg_id;
    reg [7:0] msg_idx;

    wire unused_dbg_rx = uart_dbg_rx;

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200), .STOP_BITS(1)) u_dbg_tx (
        .clk(clk_100mhz), .rst_n(rst_n),
        .tx_data(dbg_tx_data), .tx_start(dbg_tx_start),
        .tx(uart_dbg_tx), .tx_busy(dbg_tx_busy), .tx_done()
    );

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(57600), .STOP_BITS(1)) u_fp_tx (
        .clk(clk_100mhz), .rst_n(rst_n),
        .tx_data(fp_tx_data), .tx_start(fp_tx_start),
        .tx(fp_sensor_tx), .tx_busy(fp_tx_busy), .tx_done()
    );

    uart_rx #(.CLK_FREQ(100_000_000), .BAUD_RATE(57600), .STOP_BITS(1)) u_fp_rx (
        .clk(clk_100mhz), .rst_n(rst_n),
        .rx(fp_sensor_rx), .rx_data(fp_rx_data), .rx_valid(fp_rx_valid)
    );

    function [7:0] hex_char;
        input [3:0] value;
        begin
            hex_char = (value < 4'd10) ? (8'h30 + value) : (8'h37 + value);
        end
    endfunction

    function [7:0] msg_char;
        input [3:0] id;
        input [7:0] idx;
        begin
            msg_char = 8'h00;
            case (id)
                MSG_BANNER: begin
                    case (idx)
                        0: msg_char=8'h0D; 1: msg_char=8'h0A;
                        2: msg_char="A"; 3: msg_char="S"; 4: msg_char="6"; 5: msg_char="0";
                        6: msg_char="8"; 7: msg_char=" "; 8: msg_char="i"; 9: msg_char="n";
                        10: msg_char="i"; 11: msg_char="t"; 12: msg_char=" "; 13: msg_char="v";
                        14: msg_char="e"; 15: msg_char="r"; 16: msg_char="i"; 17: msg_char="f";
                        18: msg_char="y"; 19: msg_char=8'h0D; 20: msg_char=8'h0A;
                    endcase
                end
                MSG_WAKE: begin
                    case (idx)
                        0: msg_char="w"; 1: msg_char="a"; 2: msg_char="k"; 3: msg_char="e";
                        4: msg_char=" "; 5: msg_char="5"; 6: msg_char="5"; 7: msg_char=8'h0D;
                        8: msg_char=8'h0A;
                    endcase
                end
                MSG_VFYPWD: begin
                    case (idx)
                        0: msg_char="V"; 1: msg_char="f"; 2: msg_char="y"; 3: msg_char="P";
                        4: msg_char="w"; 5: msg_char="d"; 6: msg_char=8'h0D; 7: msg_char=8'h0A;
                    endcase
                end
                MSG_READSYS: begin
                    case (idx)
                        0: msg_char="R"; 1: msg_char="e"; 2: msg_char="a"; 3: msg_char="d";
                        4: msg_char="S"; 5: msg_char="y"; 6: msg_char="s"; 7: msg_char="P";
                        8: msg_char="a"; 9: msg_char="r"; 10: msg_char="a"; 11: msg_char=8'h0D;
                        12: msg_char=8'h0A;
                    endcase
                end
                MSG_VALIDNUM: begin
                    case (idx)
                        0: msg_char="V"; 1: msg_char="a"; 2: msg_char="l"; 3: msg_char="i";
                        4: msg_char="d"; 5: msg_char="T"; 6: msg_char="m"; 7: msg_char="p";
                        8: msg_char="l"; 9: msg_char="N"; 10: msg_char="u"; 11: msg_char="m";
                        12: msg_char=8'h0D; 13: msg_char=8'h0A;
                    endcase
                end
                MSG_ACK: begin
                    case (idx)
                        0: msg_char="A"; 1: msg_char="C"; 2: msg_char="K"; 3: msg_char="=";
                        4: msg_char="0"; 5: msg_char="x";
                    endcase
                end
                MSG_CNT: begin
                    case (idx)
                        0: msg_char=" "; 1: msg_char="C"; 2: msg_char="N"; 3: msg_char="T";
                        4: msg_char="="; 5: msg_char="0"; 6: msg_char="x";
                    endcase
                end
                MSG_LAST: begin
                    case (idx)
                        0: msg_char=" "; 1: msg_char="L"; 2: msg_char="A"; 3: msg_char="S";
                        4: msg_char="T"; 5: msg_char="="; 6: msg_char="0"; 7: msg_char="x";
                    endcase
                end
                MSG_CRLF: begin
                    case (idx)
                        0: msg_char=8'h0D; 1: msg_char=8'h0A;
                    endcase
                end
                MSG_TIMEOUT: begin
                    case (idx)
                        0: msg_char="t"; 1: msg_char="i"; 2: msg_char="m"; 3: msg_char="e";
                        4: msg_char="o"; 5: msg_char="u"; 6: msg_char="t"; 7: msg_char=8'h0D;
                        8: msg_char=8'h0A;
                    endcase
                end
                MSG_OK: begin
                    case (idx)
                        0: msg_char="I"; 1: msg_char="N"; 2: msg_char="I"; 3: msg_char="T";
                        4: msg_char=" "; 5: msg_char="O"; 6: msg_char="K"; 7: msg_char=8'h0D;
                        8: msg_char=8'h0A;
                    endcase
                end
            endcase
        end
    endfunction

    task start_msg;
        input [3:0] id;
        input [7:0] next_state;
        begin
            msg_id <= id;
            msg_idx <= 8'd0;
            return_state <= next_state;
            state <= S_PRINT_CHAR;
        end
    endtask

    task load_command;
        input [1:0] id;
        begin
            cmd_buf[0] <= 8'hEF; cmd_buf[1] <= 8'h01;
            cmd_buf[2] <= 8'hFF; cmd_buf[3] <= 8'hFF;
            cmd_buf[4] <= 8'hFF; cmd_buf[5] <= 8'hFF;
            cmd_buf[6] <= 8'h01;
            if (id == CMD_VFYPWD) begin
                cmd_buf[7] <= 8'h00; cmd_buf[8] <= 8'h07; cmd_buf[9] <= 8'h13;
                cmd_buf[10] <= 8'h00; cmd_buf[11] <= 8'h00;
                cmd_buf[12] <= 8'h00; cmd_buf[13] <= 8'h00;
                cmd_buf[14] <= 8'h00; cmd_buf[15] <= 8'h1B;
                cmd_len <= 5'd16;
            end else if (id == CMD_READSYS) begin
                cmd_buf[7] <= 8'h00; cmd_buf[8] <= 8'h03; cmd_buf[9] <= 8'h0F;
                cmd_buf[10] <= 8'h00; cmd_buf[11] <= 8'h13;
                cmd_len <= 5'd12;
            end else begin
                cmd_buf[7] <= 8'h00; cmd_buf[8] <= 8'h03; cmd_buf[9] <= 8'h1D;
                cmd_buf[10] <= 8'h00; cmd_buf[11] <= 8'h21;
                cmd_len <= 5'd12;
            end
        end
    endtask

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_BOOT_WAIT;
            return_state <= S_BOOT_WAIT;
            timer <= 32'd0;
            cmd_id <= CMD_VFYPWD;
            cmd_len <= 5'd0;
            cmd_idx <= 5'd0;
            rsp_idx <= 6'd0;
            rsp_total <= 6'd0;
            rsp_ack <= 8'hFF;
            rsp_count <= 8'd0;
            last_rx <= 8'd0;
            fp_tx_data <= 8'd0;
            fp_tx_start <= 1'b0;
            dbg_tx_data <= 8'd0;
            dbg_tx_start <= 1'b0;
            msg_id <= MSG_BANNER;
            msg_idx <= 8'd0;
            led <= 4'b0000;
        end else begin
            fp_tx_start <= 1'b0;
            dbg_tx_start <= 1'b0;

            case (state)
                S_BOOT_WAIT: begin
                    led <= 4'b0001;
                    if (timer >= BOOT_DELAY) begin
                        timer <= 32'd0;
                        start_msg(MSG_BANNER, S_WAKE_SEND);
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                S_WAKE_SEND: begin
                    if (msg_id != MSG_WAKE)
                        start_msg(MSG_WAKE, S_WAKE_SEND);
                    else if (!fp_tx_busy) begin
                        led <= 4'b0011;
                        fp_tx_data <= 8'h55;
                        fp_tx_start <= 1'b1;
                        timer <= 32'd0;
                        state <= S_WAKE_WAIT;
                    end
                end

                S_WAKE_WAIT: begin
                    if (timer >= WAKE_DELAY) begin
                        timer <= 32'd0;
                        cmd_id <= CMD_VFYPWD;
                        state <= S_CMD_PREP;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                S_CMD_PREP: begin
                    load_command(cmd_id);
                    cmd_idx <= 5'd0;
                    rsp_idx <= 6'd0;
                    rsp_total <= 6'd0;
                    rsp_ack <= 8'hFF;
                    rsp_count <= 8'd0;
                    last_rx <= 8'd0;
                    timer <= 32'd0;
                    if (cmd_id == CMD_VFYPWD)
                        start_msg(MSG_VFYPWD, S_CMD_SEND);
                    else if (cmd_id == CMD_READSYS)
                        start_msg(MSG_READSYS, S_CMD_SEND);
                    else
                        start_msg(MSG_VALIDNUM, S_CMD_SEND);
                end

                S_CMD_SEND: begin
                    if (cmd_idx < cmd_len) begin
                        if (!fp_tx_busy) begin
                            fp_tx_data <= cmd_buf[cmd_idx];
                            fp_tx_start <= 1'b1;
                            cmd_idx <= cmd_idx + 5'd1;
                            timer <= 32'd0;
                            state <= S_CMD_GAP;
                        end
                    end else begin
                        timer <= 32'd0;
                        rsp_idx <= 6'd0;
                        rsp_total <= 6'd0;
                        state <= S_RECV;
                    end
                end

                S_CMD_GAP: begin
                    if (timer >= BYTE_GAP) begin
                        timer <= 32'd0;
                        state <= S_CMD_SEND;
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                S_RECV: begin
                    if (fp_rx_valid) begin
                        led[1] <= 1'b1;
                        if (rsp_idx < 6'd32)
                            rsp_buf[rsp_idx] <= fp_rx_data;
                        last_rx <= fp_rx_data;
                        if (rsp_idx == 6'd8)
                            rsp_total <= 6'd9 + {1'b0, fp_rx_data[4:0]};
                        if (rsp_idx == 6'd9)
                            rsp_ack <= fp_rx_data;
                        if (rsp_total != 6'd0 && (rsp_idx + 6'd1) >= rsp_total) begin
                            rsp_count <= {2'b00, rsp_idx + 6'd1};
                            timer <= 32'd0;
                            state <= S_RESULT_ACK_MSG;
                        end else begin
                            rsp_idx <= rsp_idx + 6'd1;
                            timer <= 32'd0;
                        end
                    end else if (timer >= RX_TIMEOUT) begin
                        led[3] <= 1'b1;
                        rsp_count <= {2'b00, rsp_idx};
                        start_msg(MSG_TIMEOUT, S_RESULT_ACK_MSG);
                    end else begin
                        timer <= timer + 32'd1;
                    end
                end

                S_RESULT_ACK_MSG: start_msg(MSG_ACK, S_RESULT_ACK_H);

                S_RESULT_ACK_H: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(rsp_ack[7:4]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_ACK_L;
                    end
                end

                S_RESULT_ACK_L: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(rsp_ack[3:0]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_CNT_MSG;
                    end
                end

                S_RESULT_CNT_MSG: start_msg(MSG_CNT, S_RESULT_CNT_H);

                S_RESULT_CNT_H: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(rsp_count[7:4]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_CNT_L;
                    end
                end

                S_RESULT_CNT_L: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(rsp_count[3:0]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_LAST_MSG;
                    end
                end

                S_RESULT_LAST_MSG: start_msg(MSG_LAST, S_RESULT_LAST_H);

                S_RESULT_LAST_H: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(last_rx[7:4]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_LAST_L;
                    end
                end

                S_RESULT_LAST_L: begin
                    if (!dbg_tx_busy) begin
                        dbg_tx_data <= hex_char(last_rx[3:0]);
                        dbg_tx_start <= 1'b1;
                        state <= S_RESULT_CRLF;
                    end
                end

                S_RESULT_CRLF: start_msg(MSG_CRLF, S_NEXT_CMD);

                S_NEXT_CMD: begin
                    if (cmd_id == CMD_VFYPWD && rsp_ack == 8'h00) begin
                        cmd_id <= CMD_READSYS;
                        state <= S_CMD_PREP;
                    end else if (cmd_id == CMD_READSYS) begin
                        cmd_id <= CMD_VALIDNUM;
                        state <= S_CMD_PREP;
                    end else if (cmd_id == CMD_VALIDNUM) begin
                        led <= 4'b0111;
                        start_msg(MSG_OK, S_DONE);
                    end else begin
                        led[3] <= 1'b1;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    led[2] <= 1'b1;
                end

                S_PRINT_CHAR: begin
                    if (msg_char(msg_id, msg_idx) == 8'h00) begin
                        state <= return_state;
                    end else if (!dbg_tx_busy) begin
                        dbg_tx_data <= msg_char(msg_id, msg_idx);
                        dbg_tx_start <= 1'b1;
                        msg_idx <= msg_idx + 8'd1;
                    end
                end

                default: state <= S_BOOT_WAIT;
            endcase
        end
    end

endmodule
