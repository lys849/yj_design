//=============================================================================
// as608_ctrl.v — AS608 Fingerprint Sensor Controller + Demo State Machine
//
// Fixes:
//   - 500ms power-on boot delay before first command
//   - Dynamic response length parsing (reads pkt_len from header bytes 7-8)
//   - Waits for COMPLETE response before exiting S_CMD_RECV
//   - Inter-byte gap (200us) during command transmission
//   - RX flush between commands (discard stale bytes)
//   - Init retry: 3 attempts before declaring failure
//   - Prints error code on failure for debugging
//=============================================================================

module as608_ctrl (
    input  wire       clk,
    input  wire       rst_n,

    // AS608 UART (57600 bps)
    output reg  [7:0] fp_tx_data,
    output reg        fp_tx_send,
    input  wire       fp_tx_busy,
    input  wire [7:0] fp_rx_data,
    input  wire       fp_rx_valid,

    // Debug UART (115200 bps)
    output reg  [7:0] dbg_tx_data,
    output reg        dbg_tx_send,
    input  wire       dbg_tx_busy,

    // LEDs & Buttons
    output reg  [3:0] led,
    input  wire [1:0] btn
);

    //=========================================================================
    // Timing (100 MHz)
    //=========================================================================
    localparam [27:0] BOOT_DELAY   = 28'd10_000_000;   // 100ms power-on delay
    localparam [27:0] BYTE_GAP     = 28'd200_000;       // 2ms between bytes
    localparam [27:0] CMD_DELAY_V  = 28'd10_000_000;   // 100ms after command
    localparam [27:0] POLL_DELAY   = 28'd80_000_000;    // 800ms finger poll
    localparam [27:0] RX_TIMEOUT   = 28'd800_000_000;   // 8s response timeout

    //=========================================================================
    // Main State Machine
    //=========================================================================
    localparam S_PWRON_WAIT   = 7'd0;
    localparam S_INIT_MSG     = 7'd1;
    localparam S_INIT_RDSYS   = 7'd2;
    localparam S_INIT_CHK1    = 7'd3;
    localparam S_INIT_CNT     = 7'd4;
    localparam S_INIT_CHK2    = 7'd5;
    localparam S_INIT_DONE    = 7'd6;
    localparam S_IDLE         = 7'd7;
    localparam S_WAIT_BTNREL  = 7'd8;
    localparam S_ENROLL_IMG1  = 7'd9;
    localparam S_ENROLL_GEN1  = 7'd10;
    localparam S_ENROLL_IMG2  = 7'd11;
    localparam S_ENROLL_GEN2  = 7'd12;
    localparam S_ENROLL_MERGE = 7'd13;
    localparam S_ENROLL_STORE = 7'd14;
    localparam S_IDENT_IMG    = 7'd15;
    localparam S_IDENT_GEN    = 7'd16;
    localparam S_IDENT_SEARCH = 7'd17;
    localparam S_DONE_OK      = 7'd18;
    localparam S_DONE_FAIL    = 7'd19;
    localparam S_CMD_PREP     = 7'd20;
    localparam S_CMD_SEND     = 7'd21;
    localparam S_CMD_GAP      = 7'd22;
    localparam S_CMD_RECV     = 7'd23;
    localparam S_CMD_WAIT_END = 7'd24;
    localparam S_FLUSH_RX     = 7'd25;
    localparam S_PRINT_MSG    = 7'd26;
    localparam S_CMD_DELAY    = 7'd30;
    localparam S_READ_SYSPARA = 7'd29;
    localparam S_WAIT_BOOT    = 7'd28;
    localparam S_DELAY        = 7'd27;
    localparam S_ERROR_HALT   = 7'd63;

    reg [6:0]  state, return_state;
    reg [2:0]  init_retry;
    reg [2:0]  init_step;       // Init message sequencer (0..4)

    //=========================================================================
    // Command Buffer
    //=========================================================================
    reg [7:0]  cmd_buf [0:31];
    reg [4:0]  cmd_len;
    reg [4:0]  cmd_idx;

    //=========================================================================
    // Response Buffer
    //=========================================================================
    reg [7:0]  rsp_buf [0:31];
    reg [7:0]  rsp_exp_total;    // Expected total response bytes (9 + pkt_len)
    reg [4:0]  rsp_idx;
    reg [7:0]  rsp_ack;
    reg [15:0] rsp_data1;
    reg [15:0] rsp_data2;
    reg [7:0]  rsp_got;          // Bytes received in S_CMD_RECV window
    reg [7:0]  tx_sent;          // Bytes sent in last command
    reg        any_rx_ever;      // ANY fp_rx_valid ever seen (global)

    //=========================================================================
    // State
    //=========================================================================
    reg [15:0] tmpl_count;
    reg [15:0] lib_size;
    reg [15:0] enroll_id;
    reg [15:0] match_id;
    reg [15:0] match_score;
    reg        sensor_ok;
    reg [7:0]  error_code;

    //=========================================================================
    // Timer
    //=========================================================================
    reg [27:0] timer;
    reg        timer_en;

    //=========================================================================
    // Message output
    //=========================================================================
    reg [5:0]  msg_id;
    reg [7:0]  msg_idx;
    reg [7:0]  msg_char;
    reg        msg_active;
    // When we need to print a msg and THEN go somewhere:
    reg [6:0]  after_msg_state;

    function [7:0] h2a;
        input [3:0] n;
        begin
            h2a = (n < 4'd10) ? (8'h30 + n) : (8'h37 + n);
        end
    endfunction

    //=========================================================================
    // Main FSM
    //=========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_PWRON_WAIT;
            return_state   <= S_PWRON_WAIT;
            after_msg_state<= S_IDLE;
            init_retry     <= 3'd0;
            init_step      <= 3'd0;
            led            <= 4'b0000;
            fp_tx_data     <= 8'd0;
            fp_tx_send     <= 1'b0;
            dbg_tx_data    <= 8'd0;
            dbg_tx_send    <= 1'b0;
            msg_id         <= 6'd0;
            msg_idx        <= 8'd0;
            msg_char       <= 8'd0;
            msg_active     <= 1'b0;
            cmd_idx        <= 5'd0;
            cmd_len        <= 5'd0;
            rsp_idx        <= 5'd0;
            rsp_exp_total  <= 8'd12;
            rsp_ack        <= 8'hFF;
            rsp_data1      <= 16'd0;
            rsp_data2      <= 16'd0;
            rsp_got        <= 8'd0;
            tx_sent        <= 8'd0;
            any_rx_ever    <= 1'b0;
            tmpl_count     <= 16'd0;
            lib_size       <= 16'd300;
            enroll_id      <= 16'd0;
            match_id       <= 16'd0;
            match_score    <= 16'd0;
            sensor_ok      <= 1'b0;
            error_code     <= 8'd0;
            timer_en       <= 1'b0;
        end else begin

            // ---- Global RX activity detector (any fp_rx_valid, any time) ----
            if (fp_rx_valid)
                any_rx_ever <= 1'b1;

            // ---- Timer countdown (every cycle) ----
            if (timer_en && timer > 0)
                timer <= timer - 28'd1;
            else if (timer == 28'd0)
                timer_en <= 1'b0;

            // Default: de-assert pulses (overridden below when needed)
            fp_tx_send  <= 1'b0;
            dbg_tx_send <= 1'b0;

            // ---- Message printer (runs whenever msg_active is set) ----
            if (msg_active) begin
                if (!dbg_tx_busy && !dbg_tx_send) begin
                    case (msg_id)
                        // 0: "========================================\r\n"
                        6'd0: begin
                            case (msg_idx)
                            0: msg_char="="; 1: msg_char="="; 2: msg_char="="; 3: msg_char="=";
                            4: msg_char="="; 5: msg_char="="; 6: msg_char="="; 7: msg_char="=";
                            8: msg_char="="; 9: msg_char="="; 10:msg_char="="; 11:msg_char="=";
                            12:msg_char="="; 13:msg_char="="; 14:msg_char="="; 15:msg_char="=";
                            16:msg_char="="; 17:msg_char="="; 18:msg_char="="; 19:msg_char="=";
                            20:msg_char="="; 21:msg_char="="; 22:msg_char="="; 23:msg_char="=";
                            24:msg_char="="; 25:msg_char="="; 26:msg_char="="; 27:msg_char="=";
                            28:msg_char="="; 29:msg_char="="; 30:msg_char="="; 31:msg_char="=";
                            32:msg_char="="; 33:msg_char="="; 34:msg_char="="; 35:msg_char="=";
                            36:msg_char="="; 37:msg_char="="; 38:msg_char="="; 39:msg_char=8'h0D;
                            40:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 1: " AS608 Fingerprint Demo (Nexys4 DDR)\r\n"
                        6'd1: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char="A"; 2: msg_char="S"; 3: msg_char="6";
                            4: msg_char="0"; 5: msg_char="8"; 6: msg_char=" "; 7: msg_char="F";
                            8: msg_char="i"; 9: msg_char="n"; 10:msg_char="g"; 11:msg_char="e";
                            12:msg_char="r"; 13:msg_char="p"; 14:msg_char="r"; 15:msg_char="i";
                            16:msg_char="n"; 17:msg_char="t"; 18:msg_char=" "; 19:msg_char="D";
                            20:msg_char="e"; 21:msg_char="m"; 22:msg_char="o"; 23:msg_char=" ";
                            24:msg_char="("; 25:msg_char="N"; 26:msg_char="e"; 27:msg_char="x";
                            28:msg_char="y"; 29:msg_char="s"; 30:msg_char="4"; 31:msg_char=" ";
                            32:msg_char="D"; 33:msg_char="D"; 34:msg_char="R"; 35:msg_char=")";
                            36:msg_char=8'h0D; 37:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 2: "\r\n--- Sensor Init ---\r\n"
                        6'd2: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char="-"; 3: msg_char="-"; 4: msg_char="-"; 5: msg_char=" ";
                            6: msg_char="S"; 7: msg_char="e"; 8: msg_char="n"; 9: msg_char="s";
                            10:msg_char="o"; 11:msg_char="r"; 12:msg_char=" "; 13:msg_char="I";
                            14:msg_char="n"; 15:msg_char="i"; 16:msg_char="t"; 17:msg_char=" ";
                            18:msg_char="-"; 19:msg_char="-"; 20:msg_char="-"; 21:msg_char=8'h0D;
                            22:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 3: "  Sensor OK. Lib="
                        6'd3: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="S"; 3: msg_char="e";
                            4: msg_char="n"; 5: msg_char="s"; 6: msg_char="o"; 7: msg_char="r";
                            8: msg_char=" "; 9: msg_char="O"; 10:msg_char="K"; 11:msg_char=".";
                            12:msg_char=" "; 13:msg_char="L"; 14:msg_char="i"; 15:msg_char="b";
                            16:msg_char="=";
                            17:msg_char= h2a(lib_size[15:12]); 18:msg_char= h2a(lib_size[11:8]);
                            19:msg_char= h2a(lib_size[7:4]);  20:msg_char= h2a(lib_size[3:0]);
                            21:msg_char=8'h0D; 22:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 4: "  Stored: "
                        6'd4: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="S"; 3: msg_char="t";
                            4: msg_char="o"; 5: msg_char="r"; 6: msg_char="e"; 7: msg_char="d";
                            8: msg_char=":"; 9: msg_char=" ";
                            10:msg_char= h2a(tmpl_count[15:12]); 11:msg_char= h2a(tmpl_count[11:8]);
                            12:msg_char= h2a(tmpl_count[7:4]);  13:msg_char= h2a(tmpl_count[3:0]);
                            14:msg_char=8'h0D; 15:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 5: "*** FAILED! TX=XX RX=XX B0=XX code=XX ***\r\n"
                        6'd5: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char="*"; 3: msg_char="*"; 4: msg_char="*"; 5: msg_char=" ";
                            6: msg_char="F"; 7: msg_char="A"; 8: msg_char="I"; 9: msg_char="L";
                            10:msg_char="!"; 11:msg_char=" "; 12:msg_char="T"; 13:msg_char="X";
                            14:msg_char="=";
                            15:msg_char= h2a(tx_sent[7:4]);
                            16:msg_char= h2a(tx_sent[3:0]);
                            17:msg_char=" "; 18:msg_char="R"; 19:msg_char="X"; 20:msg_char="=";
                            21:msg_char= h2a(rsp_got[7:4]);
                            22:msg_char= h2a(rsp_got[3:0]);
                            23:msg_char=" "; 24:msg_char="B"; 25:msg_char="0"; 26:msg_char="=";
                            27:msg_char= h2a(rsp_buf[0][7:4]);
                            28:msg_char= h2a(rsp_buf[0][3:0]);
                            29:msg_char=" "; 30:msg_char="c"; 31:msg_char="=";
                            32:msg_char= h2a(error_code[7:4]);
                            33:msg_char= h2a(error_code[3:0]);
                            34:msg_char=" "; 35:msg_char="*"; 36:msg_char="*"; 37:msg_char="*";
                            38:msg_char=8'h0D; 39:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 6: "\r\n[Enroll] Place finger...\r\n"
                        6'd6: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char="["; 3: msg_char="E"; 4: msg_char="n"; 5: msg_char="r";
                            6: msg_char="o"; 7: msg_char="l"; 8: msg_char="l"; 9: msg_char="]";
                            10:msg_char=" "; 11:msg_char="P"; 12:msg_char="l"; 13:msg_char="a";
                            14:msg_char="c"; 15:msg_char="e"; 16:msg_char=" "; 17:msg_char="f";
                            18:msg_char="i"; 19:msg_char="n"; 20:msg_char="g"; 21:msg_char="e";
                            22:msg_char="r"; 23:msg_char="."; 24:msg_char="."; 25:msg_char=".";
                            26:msg_char=8'h0D; 27:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 7: "[Enroll] Remove & place again...\r\n"
                        6'd7: begin
                            case (msg_idx)
                            0: msg_char="["; 1: msg_char="E"; 2: msg_char="n"; 3: msg_char="r";
                            4: msg_char="o"; 5: msg_char="l"; 6: msg_char="l"; 7: msg_char="]";
                            8: msg_char=" "; 9: msg_char="R"; 10:msg_char="e"; 11:msg_char="m";
                            12:msg_char="o"; 13:msg_char="v"; 14:msg_char="e"; 15:msg_char=" ";
                            16:msg_char="&"; 17:msg_char=" "; 18:msg_char="p"; 19:msg_char="l";
                            20:msg_char="a"; 21:msg_char="c"; 22:msg_char="e"; 23:msg_char=" ";
                            24:msg_char="a"; 25:msg_char="g"; 26:msg_char="a"; 27:msg_char="i";
                            28:msg_char="n"; 29:msg_char="."; 30:msg_char="."; 31:msg_char=".";
                            32:msg_char=8'h0D; 33:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 8: "  -> Enroll OK! ID="
                        6'd8: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="-"; 3: msg_char=">";
                            4: msg_char=" "; 5: msg_char="E"; 6: msg_char="n"; 7: msg_char="r";
                            8: msg_char="o"; 9: msg_char="l"; 10:msg_char="l"; 11:msg_char=" ";
                            12:msg_char="O"; 13:msg_char="K"; 14:msg_char="!"; 15:msg_char=" ";
                            16:msg_char="I"; 17:msg_char="D"; 18:msg_char="=";
                            19:msg_char= h2a(enroll_id[15:12]); 20:msg_char= h2a(enroll_id[11:8]);
                            21:msg_char= h2a(enroll_id[7:4]);  22:msg_char= h2a(enroll_id[3:0]);
                            23:msg_char=8'h0D; 24:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 9: "\r\n[Identify] Place finger...\r\n"
                        6'd9: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char="["; 3: msg_char="I"; 4: msg_char="d"; 5: msg_char="e";
                            6: msg_char="n"; 7: msg_char="t"; 8: msg_char="i"; 9: msg_char="f";
                            10:msg_char="y"; 11:msg_char="]"; 12:msg_char=" "; 13:msg_char="P";
                            14:msg_char="l"; 15:msg_char="a"; 16:msg_char="c"; 17:msg_char="e";
                            18:msg_char=" "; 19:msg_char="f"; 20:msg_char="i"; 21:msg_char="n";
                            22:msg_char="g"; 23:msg_char="e"; 24:msg_char="r"; 25:msg_char=".";
                            26:msg_char="."; 27:msg_char="."; 28:msg_char=8'h0D; 29:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 10: "  -> Match! ID=xxxx Score=xxxx\r\n"
                        6'd10: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="-"; 3: msg_char=">";
                            4: msg_char=" "; 5: msg_char="M"; 6: msg_char="a"; 7: msg_char="t";
                            8: msg_char="c"; 9: msg_char="h"; 10:msg_char="!"; 11:msg_char=" ";
                            12:msg_char="I"; 13:msg_char="D"; 14:msg_char="=";
                            15:msg_char= h2a(match_id[15:12]); 16:msg_char= h2a(match_id[11:8]);
                            17:msg_char= h2a(match_id[7:4]);  18:msg_char= h2a(match_id[3:0]);
                            19:msg_char=" "; 20:msg_char="S"; 21:msg_char="c"; 22:msg_char="o";
                            23:msg_char="r"; 24:msg_char="e"; 25:msg_char="=";
                            26:msg_char= h2a(match_score[15:12]); 27:msg_char= h2a(match_score[11:8]);
                            28:msg_char= h2a(match_score[7:4]);  29:msg_char= h2a(match_score[3:0]);
                            30:msg_char=8'h0D; 31:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 11: "  -> No match found.\r\n"
                        6'd11: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="-"; 3: msg_char=">";
                            4: msg_char=" "; 5: msg_char="N"; 6: msg_char="o"; 7: msg_char=" ";
                            8: msg_char="m"; 9: msg_char="a"; 10:msg_char="t"; 11:msg_char="c";
                            12:msg_char="h"; 13:msg_char=" "; 14:msg_char="f"; 15:msg_char="o";
                            16:msg_char="u"; 17:msg_char="n"; 18:msg_char="d"; 19:msg_char=".";
                            20:msg_char=8'h0D; 21:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 12: "  FAIL: 0x**\r\n"
                        6'd12: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="F"; 3: msg_char="A";
                            4: msg_char="I"; 5: msg_char="L"; 6: msg_char=":"; 7: msg_char=" ";
                            8: msg_char="0"; 9: msg_char="x";
                            10:msg_char= h2a(error_code[7:4]);
                            11:msg_char= h2a(error_code[3:0]);
                            12:msg_char=8'h0D; 13:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 13: "\r\nBTNC=Enroll  BTNU=Identify\r\n"
                        6'd13: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char="B"; 3: msg_char="T"; 4: msg_char="N"; 5: msg_char="C";
                            6: msg_char="="; 7: msg_char="E"; 8: msg_char="n"; 9: msg_char="r";
                            10:msg_char="o"; 11:msg_char="l"; 12:msg_char="l"; 13:msg_char=" ";
                            14:msg_char=" "; 15:msg_char="B"; 16:msg_char="T"; 17:msg_char="N";
                            18:msg_char="U"; 19:msg_char="="; 20:msg_char="I"; 21:msg_char="d";
                            22:msg_char="e"; 23:msg_char="n"; 24:msg_char="t"; 25:msg_char="i";
                            26:msg_char="f"; 27:msg_char="y"; 28:msg_char=8'h0D; 29:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 14: "\r\n  Library empty! Enroll first.\r\n"
                        6'd14: begin
                            case (msg_idx)
                            0: msg_char=8'h0D; 1: msg_char=8'h0A;
                            2: msg_char=" "; 3: msg_char=" "; 4: msg_char="L"; 5: msg_char="i";
                            6: msg_char="b"; 7: msg_char="r"; 8: msg_char="a"; 9: msg_char="r";
                            10:msg_char="y"; 11:msg_char=" "; 12:msg_char="e"; 13:msg_char="m";
                            14:msg_char="p"; 15:msg_char="t"; 16:msg_char="y"; 17:msg_char="!";
                            18:msg_char=" "; 19:msg_char="E"; 20:msg_char="n"; 21:msg_char="r";
                            22:msg_char="o"; 23:msg_char="l"; 24:msg_char="l"; 25:msg_char=" ";
                            26:msg_char="f"; 27:msg_char="i"; 28:msg_char="r"; 29:msg_char="s";
                            30:msg_char="t"; 31:msg_char="."; 32:msg_char=8'h0D; 33:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 15: "  Image captured.\r\n"
                        6'd15: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="I"; 3: msg_char="m";
                            4: msg_char="a"; 5: msg_char="g"; 6: msg_char="e"; 7: msg_char=" ";
                            8: msg_char="c"; 9: msg_char="a"; 10:msg_char="p"; 11:msg_char="t";
                            12:msg_char="u"; 13:msg_char="r"; 14:msg_char="e"; 15:msg_char="d";
                            16:msg_char="."; 17:msg_char=8'h0D; 18:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 16: "  Sending init cmd...\r\n"
                        6'd16: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="S"; 3: msg_char="e";
                            4: msg_char="n"; 5: msg_char="d"; 6: msg_char="i"; 7: msg_char="n";
                            8: msg_char="g"; 9: msg_char=" "; 10:msg_char="i"; 11:msg_char="n";
                            12:msg_char="i"; 13:msg_char="t"; 14:msg_char=" "; 15:msg_char="c";
                            16:msg_char="m"; 17:msg_char="d"; 18:msg_char="."; 19:msg_char=".";
                            20:msg_char="."; 21:msg_char=8'h0D; 22:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        // 17: "  TX=XX RX=00 (timeout)\r\n"
                        6'd17: begin
                            case (msg_idx)
                            0: msg_char=" "; 1: msg_char=" "; 2: msg_char="T"; 3: msg_char="X";
                            4: msg_char="=";
                            5: msg_char= h2a(tx_sent[7:4]);
                            6: msg_char= h2a(tx_sent[3:0]);
                            7: msg_char=" "; 8: msg_char="R"; 9: msg_char="X"; 10:msg_char="=";
                            11:msg_char= h2a(rsp_got[7:4]);
                            12:msg_char= h2a(rsp_got[3:0]);
                            13:msg_char=" "; 14:msg_char="("; 15:msg_char="t"; 16:msg_char="i";
                            17:msg_char="m"; 18:msg_char="e"; 19:msg_char="o"; 20:msg_char="u";
                            21:msg_char="t"; 22:msg_char=")"; 23:msg_char=8'h0D; 24:msg_char=8'h0A;
                            default: msg_active <= 1'b0;
                            endcase
                        end
                        default: msg_active <= 1'b0;
                    endcase

                    // Send character via debug UART
                    dbg_tx_data <= msg_char;
                    dbg_tx_send <= 1'b1;
                    msg_idx     <= msg_idx + 8'd1;
                end
            end

            // ---- Main FSM ----
            case (state)

                //=================================================================
                // S_PWRON_WAIT: Print, wait 3s, send wake byte 0x55, wait 1s
                //=================================================================
                S_PWRON_WAIT: begin
                    case (init_step)
                        3'd0: begin
                            led[0] <= 1'b1;
                            msg_id <= 6'd2;
                            msg_idx <= 8'd0;
                            msg_active <= 1'b1;
                            timer   <= 28'd300_000_000;  // 3s
                            timer_en <= 1'b1;
                            init_step <= 3'd1;
                            state <= S_PRINT_MSG;
                            after_msg_state <= S_PWRON_WAIT;
                        end
                        3'd1: begin  // Send wake byte 0x55
                            if (timer == 28'd0 && !timer_en && !fp_tx_busy && !fp_tx_send) begin
                                fp_tx_data <= 8'h55;
                                fp_tx_send <= 1'b1;
                                timer   <= 28'd100_000_000;  // 1s after wake
                                timer_en <= 1'b1;
                                init_step <= 3'd2;
                            end
                        end
                        default: begin  // Wait for 1s delay, then VfyPwd
                            if (timer == 28'd0 && !timer_en) begin
                                init_step <= 3'd0;
                                state <= S_INIT_RDSYS;
                            end
                        end
                    endcase
                end

                //=================================================================
                // S_INIT_RDSYS: Send VfyPwd first (simpler, just ACK response)
                //=================================================================
                S_INIT_RDSYS: begin
                    // VfyPwd: EF01 FFFFFFFF 01 0007 13 00000000 001B
                    cmd_buf[0]<=8'hEF; cmd_buf[1]<=8'h01;
                    cmd_buf[2]<=8'hFF; cmd_buf[3]<=8'hFF;
                    cmd_buf[4]<=8'hFF; cmd_buf[5]<=8'hFF;
                    cmd_buf[6]<=8'h01; cmd_buf[7]<=8'h00; cmd_buf[8]<=8'h07;
                    cmd_buf[9]<=8'h13;  // VfyPwd cmd
                    cmd_buf[10]<=8'h00; cmd_buf[11]<=8'h00;
                    cmd_buf[12]<=8'h00; cmd_buf[13]<=8'h00;  // password=0
                    cmd_buf[14]<=8'h00; cmd_buf[15]<=8'h1B;  // checksum
                    cmd_len    <= 5'd16;
                    rsp_exp_total <= 8'd12;  // just ACK response
                    return_state  <= S_INIT_CHK1;
                    state <= S_CMD_PREP;
                end

                //=================================================================
                // S_INIT_CHK1: Check VfyPwd response
                //=================================================================
                S_INIT_CHK1: begin
                    if (rsp_ack == 8'h00) begin
                        // VfyPwd OK! Now send ReadSysPara
                        sensor_ok <= 1'b1;
                        state <= S_READ_SYSPARA;  // Next: ReadSysPara
                    end else if (rsp_ack == 8'h13) begin
                        // Wrong password — try ReadSysPara anyway
                        state <= S_INIT_RDSYS + 7'd1;
                    end else begin
                        if (init_retry < 3'd3) begin
                            init_retry <= init_retry + 3'd1;
                            timer   <= 28'd50_000_000;
                            timer_en<= 1'b1;
                            return_state <= S_INIT_RDSYS;
                            state   <= S_DELAY;
                        end else begin
                            sensor_ok  <= 1'b0;
                            error_code <= rsp_ack;
                            msg_id     <= 6'd5;
                            msg_idx    <= 8'd0;
                            msg_active <= 1'b1;
                            after_msg_state <= S_ERROR_HALT;
                            state      <= S_PRINT_MSG;
                        end
                    end
                end

                //=================================================================
                // S_READ_SYSPARA: Send ReadSysPara (after VfyPwd)
                //=================================================================
                S_READ_SYSPARA: begin
                    // ReadSysPara: EF01 FFFFFFFF 01 0003 0F 0013
                    cmd_buf[0]<=8'hEF; cmd_buf[1]<=8'h01;
                    cmd_buf[2]<=8'hFF; cmd_buf[3]<=8'hFF;
                    cmd_buf[4]<=8'hFF; cmd_buf[5]<=8'hFF;
                    cmd_buf[6]<=8'h01; cmd_buf[7]<=8'h00; cmd_buf[8]<=8'h03;
                    cmd_buf[9]<=8'h0F; cmd_buf[10]<=8'h00; cmd_buf[11]<=8'h13;
                    cmd_len    <= 5'd12;
                    rsp_exp_total <= 8'd28;
                    return_state  <= S_INIT_CHK2;
                    state <= S_CMD_PREP;
                end

                //=================================================================
                // S_INIT_CNT: Send ValidTmplNum
                //=================================================================
                S_INIT_CNT: begin
                    init_retry <= 3'd0;
                    // EF01 FFFFFFFF 01 0003 1D 0021
                    cmd_buf[0]<=8'hEF; cmd_buf[1]<=8'h01;
                    cmd_buf[2]<=8'hFF; cmd_buf[3]<=8'hFF;
                    cmd_buf[4]<=8'hFF; cmd_buf[5]<=8'hFF;
                    cmd_buf[6]<=8'h01; cmd_buf[7]<=8'h00; cmd_buf[8]<=8'h03;
                    cmd_buf[9]<=8'h1D; cmd_buf[10]<=8'h00; cmd_buf[11]<=8'h21;
                    cmd_len    <= 5'd12;
                    rsp_exp_total <= 8'd14;  // 9 + 5
                    return_state  <= S_INIT_CHK2;
                    state <= S_CMD_PREP;
                end

                S_INIT_CHK2: begin
                    if (rsp_ack == 8'h00) begin
                        tmpl_count <= {rsp_buf[1], rsp_buf[2]};
                        enroll_id  <= {rsp_buf[1], rsp_buf[2]};
                    end
                    msg_id    <= 6'd4;
                    msg_idx   <= 8'd0;
                    msg_active<= 1'b1;
                    after_msg_state <= S_INIT_DONE;
                    state     <= S_PRINT_MSG;
                end

                //=================================================================
                // S_INIT_DONE → IDLE
                //=================================================================
                S_INIT_DONE: begin
                    msg_id    <= 6'd13;
                    msg_idx   <= 8'd0;
                    msg_active<= 1'b1;
                    after_msg_state <= S_IDLE;
                    state     <= S_PRINT_MSG;
                end

                //=================================================================
                // S_IDLE: Wait for button
                //=================================================================
                S_IDLE: begin
                    led[1] <= 1'b0; led[2] <= any_rx_ever; led[3] <= 1'b0;
                    if (btn[0]) begin
                        after_msg_state <= S_ENROLL_IMG1; state <= S_WAIT_BTNREL;
                    end else if (btn[1]) begin
                        after_msg_state <= S_IDENT_IMG;  state <= S_WAIT_BTNREL;
                    end
                end

                //=================================================================
                // S_WAIT_BTNREL: Debounce
                //=================================================================
                S_WAIT_BTNREL: begin
                    timer   <= 28'd5_000_000;  // 50ms
                    timer_en<= 1'b1;
                    state   <= S_DELAY;
                    return_state <= after_msg_state;
                end

                //=================================================================
                // ENROLL flow
                //=================================================================
                //=================================================================
                // ENROLL: Use PS_Enroll (0x10) — auto: GetImage×2 + GenChar×2 + RegModel + Store
                //=================================================================
                S_ENROLL_IMG1: begin
                    led[1]     <= 1'b1;
                    msg_id     <= 6'd6;   // "Place finger..."
                    msg_idx    <= 8'd0;
                    msg_active <= 1'b1;
                    // PS_Enroll: EF01 FFFFFFFF 01 0003 10 0014
                    cmd_buf[0]<=8'hEF; cmd_buf[1]<=8'h01;
                    cmd_buf[2]<=8'hFF; cmd_buf[3]<=8'hFF;
                    cmd_buf[4]<=8'hFF; cmd_buf[5]<=8'hFF;
                    cmd_buf[6]<=8'h01; cmd_buf[7]<=8'h00; cmd_buf[8]<=8'h03;
                    cmd_buf[9]<=8'h10; cmd_buf[10]<=8'h00; cmd_buf[11]<=8'h14;
                    cmd_len    <= 5'd12;
                    rsp_exp_total <= 8'd14;  // 9hdr + 5(ack+pageid[2]+chk[2])
                    return_state  <= S_DONE_OK;
                    after_msg_state <= S_CMD_PREP;
                    state <= S_PRINT_MSG;
                end

                //=================================================================
                // IDENTIFY: Use PS_Identify (0x11) — auto: GetImage + GenChar + Search
                //=================================================================
                S_IDENT_IMG: begin
                    if (tmpl_count == 16'd0) begin
                        msg_id     <= 6'd14;
                        msg_idx    <= 8'd0;
                        msg_active <= 1'b1;
                        after_msg_state <= S_IDLE;
                        state      <= S_PRINT_MSG;
                    end else begin
                        led[2]     <= 1'b1;
                        msg_id     <= 6'd9;
                        msg_idx    <= 8'd0;
                        msg_active <= 1'b1;
                        // PS_Identify: EF01 FFFFFFFF 01 0003 11 0015
                        cmd_buf[0]<=8'hEF; cmd_buf[1]<=8'h01;
                        cmd_buf[2]<=8'hFF; cmd_buf[3]<=8'hFF;
                        cmd_buf[4]<=8'hFF; cmd_buf[5]<=8'hFF;
                        cmd_buf[6]<=8'h01; cmd_buf[7]<=8'h00; cmd_buf[8]<=8'h03;
                        cmd_buf[9]<=8'h11; cmd_buf[10]<=8'h00; cmd_buf[11]<=8'h15;
                        cmd_len    <= 5'd12;
                        rsp_exp_total <= 8'd16;
                        return_state  <= S_DONE_OK;
                        after_msg_state <= S_CMD_PREP;
                        state <= S_PRINT_MSG;
                    end
                end

                //=================================================================
                // S_DONE_OK: Check PS_Enroll / PS_Identify response
                // PS_Enroll  resp: ACK + PageID[2] + chk[2]
                // PS_Identify resp: ACK + PageID[2] + Score[2] + chk[2]
                //=================================================================
                S_DONE_OK: begin
                    if (led[1]) begin  // was enrolling (PS_Enroll)
                        if (rsp_ack == 8'h00) begin
                            // Enroll success!
                            led[1] <= 1'b0;
                            enroll_id  <= {rsp_buf[10], rsp_buf[11]};
                            tmpl_count <= tmpl_count + 16'd1;
                            msg_id     <= 6'd8;   // "Enroll OK! ID=xxxx"
                            msg_idx    <= 8'd0;
                            msg_active <= 1'b1;
                            after_msg_state <= S_IDLE;
                            state <= S_PRINT_MSG;
                        end else if (rsp_ack == 8'h02 || rsp_ack == 8'h03) begin
                            // No finger (0x02) or bad image (0x03) — retry
                            timer   <= 28'd50_000_000;  // 500ms
                            timer_en<= 1'b1;
                            state   <= S_DELAY;
                            return_state <= S_ENROLL_IMG1;
                        end else begin
                            led[1] <= 1'b0;
                            error_code <= rsp_ack;
                            state <= S_DONE_FAIL;
                        end
                    end else begin  // was identifying (PS_Identify)
                        if (rsp_ack == 8'h00) begin
                            led[2] <= 1'b0;
                            match_id    <= {rsp_buf[10], rsp_buf[11]};
                            match_score <= {rsp_buf[12], rsp_buf[13]};
                            msg_id     <= 6'd10;  // "Match!"
                            msg_idx    <= 8'd0;
                            msg_active <= 1'b1;
                            after_msg_state <= S_IDLE;
                            state <= S_PRINT_MSG;
                        end else if (rsp_ack == 8'h09) begin
                            led[2] <= 1'b0;
                            msg_id     <= 6'd11;  // "No match"
                            msg_idx    <= 8'd0;
                            msg_active <= 1'b1;
                            after_msg_state <= S_IDLE;
                            state <= S_PRINT_MSG;
                        end else if (rsp_ack == 8'h02 || rsp_ack == 8'h03) begin
                            // No finger or bad image — retry
                            timer   <= 28'd50_000_000;
                            timer_en<= 1'b1;
                            state   <= S_DELAY;
                            return_state <= S_IDENT_IMG;
                        end else begin
                            led[2] <= 1'b0;
                            error_code <= rsp_ack;
                            state <= S_DONE_FAIL;
                        end
                    end
                end

                S_DONE_FAIL: begin
                    led[1] <= 1'b0; led[2] <= 1'b0; led[3] <= 1'b1;
                    msg_id     <= 6'd12;
                    msg_idx    <= 8'd0;
                    msg_active <= 1'b1;
                    after_msg_state <= S_IDLE;
                    state <= S_PRINT_MSG;
                end

                //=================================================================
                // S_CMD_PREP: Go straight to send (no flush — keep RX data)
                //=================================================================
                S_CMD_PREP: begin
                    cmd_idx <= 5'd0;
                    timer   <= 28'd1_000_000;   // 10ms guard delay
                    timer_en<= 1'b1;
                    state   <= S_CMD_DELAY;
                end

                S_CMD_DELAY: begin
                    if (timer == 28'd0 && !timer_en) begin
                        state <= S_CMD_SEND;
                    end
                end

                //=================================================================
                // S_FLUSH_RX: Wait for timer, then go to S_CMD_SEND
                //             (does NOT use return_state — preserves it for cmd flow)
                //=================================================================
                S_FLUSH_RX: begin
                    if (timer == 28'd0 && !timer_en)
                        state <= S_CMD_SEND;
                end

                //=================================================================
                // S_CMD_SEND: Transmit command bytes with inter-byte gaps
                //=================================================================
                S_CMD_SEND: begin
                    if (cmd_idx < cmd_len) begin
                        if (!fp_tx_busy && !fp_tx_send) begin
                            fp_tx_data <= cmd_buf[cmd_idx];
                            fp_tx_send <= 1'b1;
                            cmd_idx    <= cmd_idx + 5'd1;
                            // Wait gap between bytes
                            timer   <= BYTE_GAP;
                            timer_en<= 1'b1;
                            state   <= S_CMD_GAP;
                        end
                    end else begin
                        // All bytes sent → save count, wait for response
                        tx_sent    <= cmd_len;
                        rsp_idx    <= 5'd0;
                        timer      <= RX_TIMEOUT;
                        timer_en   <= 1'b1;
                        state      <= S_CMD_RECV;
                    end
                end

                //=================================================================
                // S_CMD_GAP: Inter-byte gap
                //=================================================================
                S_CMD_GAP: begin
                    if (timer == 28'd0 && !timer_en) begin
                        state <= S_CMD_SEND;
                    end
                end

                //=================================================================
                // S_CMD_RECV: Receive response until complete or timeout
                //
                // Response format: HDR(2)+ADDR(4)+FLAG(1)+LEN(2)+PAYLOAD(LEN)
                // Total bytes = 9 + {rsp_buf[7], rsp_buf[8]}
                // After receiving all bytes, go to S_CMD_WAIT_END to
                // safely extract rsp_ack from rsp_buf[9].
                //=================================================================
                S_CMD_RECV: begin
                    if (timer == 28'd0 && !timer_en) begin
                        // Timeout — save RX count for debug
                        rsp_ack   <= 8'h12;
                        rsp_got   <= rsp_idx;
                        state     <= return_state;
                    end else if (fp_rx_valid) begin
                        // Store incoming byte
                        rsp_buf[rsp_idx] <= fp_rx_data;

                        // After receiving byte 8 (len_low), compute expected total
                        if (rsp_idx == 5'd8) begin
                            rsp_exp_total <= 9 + {rsp_buf[7], fp_rx_data};
                        end

                        // Is this the last expected byte?
                        if (rsp_idx == rsp_exp_total - 8'd1) begin
                            // Last byte — go to wait state so rsp_buf[9] is stable
                            state <= S_CMD_WAIT_END;
                        end

                        rsp_idx <= rsp_idx + 5'd1;
                        timer   <= RX_TIMEOUT;
                    end
                end

                //=================================================================
                // S_CMD_WAIT_END: Extract ACK from stable rsp_buf[9]
                //=================================================================
                S_CMD_WAIT_END: begin
                    rsp_ack <= rsp_buf[9];
                    state   <= return_state;
                end

                //=================================================================
                // S_DELAY: Generic delay
                //=================================================================
                S_DELAY: begin
                    if (timer == 28'd0 && !timer_en) begin
                        state <= return_state;
                    end
                end

                //=================================================================
                // S_PRINT_MSG: Wait for message to finish
                //=================================================================
                S_PRINT_MSG: begin
                    if (!msg_active) begin
                        state <= after_msg_state;
                    end
                end

                //=================================================================
                // S_ERROR_HALT
                //=================================================================
                S_ERROR_HALT: begin
                    led[3] <= 1'b1;   // Error
                    led[2] <= any_rx_ever;  // ON if any RX bytes seen
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule
