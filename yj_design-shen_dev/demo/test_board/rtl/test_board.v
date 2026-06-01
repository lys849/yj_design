// test_board.v - Fingerprint Payment System Board Test
// Full payment flow via UART terminal (VGA replaced by serial)
// Tests: keyboard PMOD JB, fingerprint AS608 PMOD JD, buzzer PMOD JC
`timescale 1ns / 1ps

module test_board (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output wire       debug_tx,
    output wire [3:0] kb_row,
    input  wire [3:0] kb_col,
    output wire       fp_sensor_tx,
    input  wire       fp_sensor_rx,
    output wire       buzzer
);

    // ============================================
    // Module instantiations
    // ============================================
    wire [7:0] uart_tx_data;
    reg        uart_tx_start;
    wire       uart_tx_busy, uart_tx_done;
    wire [3:0] kb_code;
    wire       kb_valid;
    reg  [7:0] fp_cmd_opcode;
    reg  [15:0] fp_cmd_param;
    reg        fp_cmd_start;
    wire [15:0] fp_response;
    wire [7:0]  fp_status;
    wire        fp_cmd_done;
    reg beep_short, beep_ok, beep_fail;

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200))
        u_uart_tx (
            .clk(clk_100mhz), .rst_n(rst_n),
            .tx_data(uart_tx_data), .tx_start(uart_tx_start),
            .tx(debug_tx), .tx_busy(uart_tx_busy), .tx_done(uart_tx_done)
        );

    keyboard_scan #(.CLK_FREQ(100_000_000))
        u_kb (
            .clk(clk_100mhz), .rst_n(rst_n),
            .row(kb_row), .col(kb_col),
            .key_code(kb_code), .key_valid(kb_valid)
        );

    fingerprint_ctrl #(.CLK_FREQ(100_000_000), .BAUD_RATE(57600))
        u_fp (
            .clk(clk_100mhz), .rst_n(rst_n),
            .sensor_tx(fp_sensor_tx), .sensor_rx(fp_sensor_rx),
            .cmd_opcode(fp_cmd_opcode), .cmd_param(fp_cmd_param),
            .cmd_start(fp_cmd_start),
            .response(fp_response), .status(fp_status), .cmd_done(fp_cmd_done)
        );

    buzzer_ctrl #(.CLK_FREQ(100_000_000))
        u_bz (
            .clk(clk_100mhz), .rst_n(rst_n),
            .beep_short(beep_short), .beep_ok(beep_ok), .beep_fail(beep_fail),
            .buzzer_out(buzzer)
        );

    // ============================================
    // FP command codes
    // ============================================
    localparam FP_GET_IMAGE  = 8'h01;
    localparam FP_GEN_CHAR   = 8'h02;
    localparam FP_SEARCH     = 8'h04;
    localparam FP_REG_MODEL  = 8'h05;
    localparam FP_STORE      = 8'h06;
    localparam FP_DELETE     = 8'h0C;
    localparam FP_READ_PARAM = 8'h0F;

    // ============================================
    // Account storage (4 slots, register-based, cents)
    // ============================================
    localparam MAX_ACCT  = 4;
    localparam MAX_FP_ID = 8'd32;
    reg [7:0]  acct_fp_id   [0:MAX_ACCT-1];
    reg [31:0] acct_balance [0:MAX_ACCT-1];
    reg        acct_active  [0:MAX_ACCT-1];
    reg [7:0]  next_fp_id;
    reg [7:0]  matched_fp_id;   // <-- declared early for always @(*) block
    integer _init_k;
    initial begin
        next_fp_id = 3;
        for (_init_k = 0; _init_k < MAX_ACCT; _init_k = _init_k + 1) begin
            acct_fp_id[_init_k]   = 0;
            acct_balance[_init_k] = 0;
            acct_active[_init_k]  = 0;
        end
        acct_fp_id[0] = 8'd1; acct_balance[0] = 32'd10000; acct_active[0] = 1;
        acct_fp_id[1] = 8'd2; acct_balance[1] = 32'd5000;  acct_active[1] = 1;
    end

    // ============================================
    // Message ROM
    // ============================================
    reg [7:0] msg_rom [0:511];

// Message IDs
localparam MSG_TITLE = 4'd0;
localparam MSG_FP_OK = 4'd1;
localparam MSG_FP_FAIL = 4'd2;
localparam MSG_MAIN_MENU = 4'd3;
localparam MSG_ACCT_MENU = 4'd4;
localparam MSG_CREATE_1 = 4'd5;
localparam MSG_CREATE_2 = 4'd6;
localparam MSG_ENTER_DEP = 4'd7;
localparam MSG_DELETE_1 = 4'd8;
localparam MSG_ACCT_INFO = 4'd9;
localparam MSG_DELETED = 4'd10;
localparam MSG_RECHARGE_1 = 4'd11;
localparam MSG_CUR_BAL = 4'd12;
localparam MSG_QUERY_1 = 4'd13;
localparam MSG_PAY_AMOUNT = 4'd14;
localparam MSG_PAY_CONFIRM = 4'd15;
localparam MSG_INSUFF = 4'd16;
localparam MSG_NO_MATCH = 4'd17;
localparam MSG_CANCELLED = 4'd18;
localparam MSG_ENROLL_FAIL = 4'd19;
localparam MSG_ANY_KEY = 4'd20;
localparam MSG_NEW_BAL = 4'd21;
localparam MSG_ACCT_ID = 4'd22;
localparam MSG_PAID = 4'd23;
localparam MSG_BAL_AFTER = 4'd24;
localparam MSG_RECHG_AMT = 4'd25;
localparam MSG_CONFIRM_DEL = 4'd26;
localparam MSG_CREATED_OK = 4'd27;
localparam MSG_RECHARGED_OK = 4'd28;
localparam MSG_PAY_OK = 4'd29;

// Message ROM arrays
reg [9:0] msg_base [0:31];
reg [6:0] msg_len  [0:31];

// ROM init
reg [9:0] _pos;
integer   _j;
initial begin : msg_init
    for (_j = 0; _j < 512; _j = _j + 1) msg_rom[_j] = 8'd0;
    _pos = 0;
    // MSG_TITLE (36B)
    msg_base[0] = _pos;
    msg_len[0]  = 7'd36;
    msg_rom[_pos+0] = "=";
    msg_rom[_pos+1] = "=";
    msg_rom[_pos+2] = "=";
    msg_rom[_pos+3] = " ";
    msg_rom[_pos+4] = "F";
    msg_rom[_pos+5] = "I";
    msg_rom[_pos+6] = "N";
    msg_rom[_pos+7] = "G";
    msg_rom[_pos+8] = "E";
    msg_rom[_pos+9] = "R";
    msg_rom[_pos+10] = "P";
    msg_rom[_pos+11] = "R";
    msg_rom[_pos+12] = "I";
    msg_rom[_pos+13] = "N";
    msg_rom[_pos+14] = "T";
    msg_rom[_pos+15] = " ";
    msg_rom[_pos+16] = "P";
    msg_rom[_pos+17] = "A";
    msg_rom[_pos+18] = "Y";
    msg_rom[_pos+19] = "M";
    msg_rom[_pos+20] = "E";
    msg_rom[_pos+21] = "N";
    msg_rom[_pos+22] = "T";
    msg_rom[_pos+23] = " ";
    msg_rom[_pos+24] = "S";
    msg_rom[_pos+25] = "Y";
    msg_rom[_pos+26] = "S";
    msg_rom[_pos+27] = "T";
    msg_rom[_pos+28] = "E";
    msg_rom[_pos+29] = "M";
    msg_rom[_pos+30] = " ";
    msg_rom[_pos+31] = "=";
    msg_rom[_pos+32] = "=";
    msg_rom[_pos+33] = "=";
    msg_rom[_pos+34] = 8'h0D;
    msg_rom[_pos+35] = 8'h0A;
    _pos = _pos + 9'd36;
    // MSG_FP_OK (15B)
    msg_base[1] = _pos;
    msg_len[1]  = 7'd15;
    msg_rom[_pos+0] = "F";
    msg_rom[_pos+1] = "P";
    msg_rom[_pos+2] = " ";
    msg_rom[_pos+3] = "S";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = "n";
    msg_rom[_pos+6] = "s";
    msg_rom[_pos+7] = "o";
    msg_rom[_pos+8] = "r";
    msg_rom[_pos+9] = ":";
    msg_rom[_pos+10] = " ";
    msg_rom[_pos+11] = "O";
    msg_rom[_pos+12] = "K";
    msg_rom[_pos+13] = 8'h0D;
    msg_rom[_pos+14] = 8'h0A;
    _pos = _pos + 9'd15;
    // MSG_FP_FAIL (17B)
    msg_base[2] = _pos;
    msg_len[2]  = 7'd17;
    msg_rom[_pos+0] = "F";
    msg_rom[_pos+1] = "P";
    msg_rom[_pos+2] = " ";
    msg_rom[_pos+3] = "S";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = "n";
    msg_rom[_pos+6] = "s";
    msg_rom[_pos+7] = "o";
    msg_rom[_pos+8] = "r";
    msg_rom[_pos+9] = ":";
    msg_rom[_pos+10] = " ";
    msg_rom[_pos+11] = "F";
    msg_rom[_pos+12] = "A";
    msg_rom[_pos+13] = "I";
    msg_rom[_pos+14] = "L";
    msg_rom[_pos+15] = 8'h0D;
    msg_rom[_pos+16] = 8'h0A;
    _pos = _pos + 9'd17;
    // MSG_MAIN_MENU (35B)
    msg_base[3] = _pos;
    msg_len[3]  = 7'd35;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "[";
    msg_rom[_pos+3] = "M";
    msg_rom[_pos+4] = "A";
    msg_rom[_pos+5] = "I";
    msg_rom[_pos+6] = "N";
    msg_rom[_pos+7] = "]";
    msg_rom[_pos+8] = 8'h0D;
    msg_rom[_pos+9] = 8'h0A;
    msg_rom[_pos+10] = " ";
    msg_rom[_pos+11] = "1";
    msg_rom[_pos+12] = ".";
    msg_rom[_pos+13] = "A";
    msg_rom[_pos+14] = "c";
    msg_rom[_pos+15] = "c";
    msg_rom[_pos+16] = "o";
    msg_rom[_pos+17] = "u";
    msg_rom[_pos+18] = "n";
    msg_rom[_pos+19] = "t";
    msg_rom[_pos+20] = " ";
    msg_rom[_pos+21] = " ";
    msg_rom[_pos+22] = "2";
    msg_rom[_pos+23] = ".";
    msg_rom[_pos+24] = "P";
    msg_rom[_pos+25] = "a";
    msg_rom[_pos+26] = "y";
    msg_rom[_pos+27] = "m";
    msg_rom[_pos+28] = "e";
    msg_rom[_pos+29] = "n";
    msg_rom[_pos+30] = "t";
    msg_rom[_pos+31] = 8'h0D;
    msg_rom[_pos+32] = 8'h0A;
    msg_rom[_pos+33] = ">";
    msg_rom[_pos+34] = " ";
    _pos = _pos + 9'd35;
    // MSG_ACCT_MENU (67B)
    msg_base[4] = _pos;
    msg_len[4]  = 7'd67;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "[";
    msg_rom[_pos+3] = "A";
    msg_rom[_pos+4] = "C";
    msg_rom[_pos+5] = "C";
    msg_rom[_pos+6] = "O";
    msg_rom[_pos+7] = "U";
    msg_rom[_pos+8] = "N";
    msg_rom[_pos+9] = "T";
    msg_rom[_pos+10] = "]";
    msg_rom[_pos+11] = 8'h0D;
    msg_rom[_pos+12] = 8'h0A;
    msg_rom[_pos+13] = " ";
    msg_rom[_pos+14] = "1";
    msg_rom[_pos+15] = ".";
    msg_rom[_pos+16] = "C";
    msg_rom[_pos+17] = "r";
    msg_rom[_pos+18] = "e";
    msg_rom[_pos+19] = "a";
    msg_rom[_pos+20] = "t";
    msg_rom[_pos+21] = "e";
    msg_rom[_pos+22] = " ";
    msg_rom[_pos+23] = " ";
    msg_rom[_pos+24] = "2";
    msg_rom[_pos+25] = ".";
    msg_rom[_pos+26] = "D";
    msg_rom[_pos+27] = "e";
    msg_rom[_pos+28] = "l";
    msg_rom[_pos+29] = "e";
    msg_rom[_pos+30] = "t";
    msg_rom[_pos+31] = "e";
    msg_rom[_pos+32] = 8'h0D;
    msg_rom[_pos+33] = 8'h0A;
    msg_rom[_pos+34] = " ";
    msg_rom[_pos+35] = "3";
    msg_rom[_pos+36] = ".";
    msg_rom[_pos+37] = "R";
    msg_rom[_pos+38] = "e";
    msg_rom[_pos+39] = "c";
    msg_rom[_pos+40] = "h";
    msg_rom[_pos+41] = "a";
    msg_rom[_pos+42] = "r";
    msg_rom[_pos+43] = "g";
    msg_rom[_pos+44] = "e";
    msg_rom[_pos+45] = " ";
    msg_rom[_pos+46] = " ";
    msg_rom[_pos+47] = "4";
    msg_rom[_pos+48] = ".";
    msg_rom[_pos+49] = "Q";
    msg_rom[_pos+50] = "u";
    msg_rom[_pos+51] = "e";
    msg_rom[_pos+52] = "r";
    msg_rom[_pos+53] = "y";
    msg_rom[_pos+54] = 8'h0D;
    msg_rom[_pos+55] = 8'h0A;
    msg_rom[_pos+56] = " ";
    msg_rom[_pos+57] = "B";
    msg_rom[_pos+58] = ":";
    msg_rom[_pos+59] = "B";
    msg_rom[_pos+60] = "a";
    msg_rom[_pos+61] = "c";
    msg_rom[_pos+62] = "k";
    msg_rom[_pos+63] = 8'h0D;
    msg_rom[_pos+64] = 8'h0A;
    msg_rom[_pos+65] = ">";
    msg_rom[_pos+66] = " ";
    _pos = _pos + 9'd67;
    // MSG_CREATE_1 (33B)
    msg_base[5] = _pos;
    msg_len[5]  = 7'd33;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "C";
    msg_rom[_pos+3] = "r";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = "a";
    msg_rom[_pos+6] = "t";
    msg_rom[_pos+7] = "e";
    msg_rom[_pos+8] = ":";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "P";
    msg_rom[_pos+11] = "l";
    msg_rom[_pos+12] = "a";
    msg_rom[_pos+13] = "c";
    msg_rom[_pos+14] = "e";
    msg_rom[_pos+15] = " ";
    msg_rom[_pos+16] = "f";
    msg_rom[_pos+17] = "i";
    msg_rom[_pos+18] = "n";
    msg_rom[_pos+19] = "g";
    msg_rom[_pos+20] = "e";
    msg_rom[_pos+21] = "r";
    msg_rom[_pos+22] = " ";
    msg_rom[_pos+23] = "(";
    msg_rom[_pos+24] = "1";
    msg_rom[_pos+25] = "/";
    msg_rom[_pos+26] = "2";
    msg_rom[_pos+27] = ")";
    msg_rom[_pos+28] = ".";
    msg_rom[_pos+29] = ".";
    msg_rom[_pos+30] = ".";
    msg_rom[_pos+31] = 8'h0D;
    msg_rom[_pos+32] = 8'h0A;
    _pos = _pos + 9'd33;
    // MSG_CREATE_2 (32B)
    msg_base[6] = _pos;
    msg_len[6]  = 7'd32;
    msg_rom[_pos+0] = "P";
    msg_rom[_pos+1] = "l";
    msg_rom[_pos+2] = "a";
    msg_rom[_pos+3] = "c";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = " ";
    msg_rom[_pos+6] = "f";
    msg_rom[_pos+7] = "i";
    msg_rom[_pos+8] = "n";
    msg_rom[_pos+9] = "g";
    msg_rom[_pos+10] = "e";
    msg_rom[_pos+11] = "r";
    msg_rom[_pos+12] = " ";
    msg_rom[_pos+13] = "(";
    msg_rom[_pos+14] = "2";
    msg_rom[_pos+15] = "/";
    msg_rom[_pos+16] = "2";
    msg_rom[_pos+17] = ")";
    msg_rom[_pos+18] = ",";
    msg_rom[_pos+19] = " ";
    msg_rom[_pos+20] = "p";
    msg_rom[_pos+21] = "r";
    msg_rom[_pos+22] = "e";
    msg_rom[_pos+23] = "s";
    msg_rom[_pos+24] = "s";
    msg_rom[_pos+25] = " ";
    msg_rom[_pos+26] = "A";
    msg_rom[_pos+27] = ".";
    msg_rom[_pos+28] = ".";
    msg_rom[_pos+29] = ".";
    msg_rom[_pos+30] = 8'h0D;
    msg_rom[_pos+31] = 8'h0A;
    _pos = _pos + 9'd32;
    // MSG_ENTER_DEP (22B)
    msg_base[7] = _pos;
    msg_len[7]  = 7'd22;
    msg_rom[_pos+0] = "E";
    msg_rom[_pos+1] = "n";
    msg_rom[_pos+2] = "t";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "r";
    msg_rom[_pos+5] = " ";
    msg_rom[_pos+6] = "d";
    msg_rom[_pos+7] = "e";
    msg_rom[_pos+8] = "p";
    msg_rom[_pos+9] = "o";
    msg_rom[_pos+10] = "s";
    msg_rom[_pos+11] = "i";
    msg_rom[_pos+12] = "t";
    msg_rom[_pos+13] = " ";
    msg_rom[_pos+14] = "(";
    msg_rom[_pos+15] = "y";
    msg_rom[_pos+16] = "u";
    msg_rom[_pos+17] = "a";
    msg_rom[_pos+18] = "n";
    msg_rom[_pos+19] = ")";
    msg_rom[_pos+20] = ":";
    msg_rom[_pos+21] = " ";
    _pos = _pos + 9'd22;
    // MSG_DELETE_1 (27B)
    msg_base[8] = _pos;
    msg_len[8]  = 7'd27;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "D";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "l";
    msg_rom[_pos+5] = "e";
    msg_rom[_pos+6] = "t";
    msg_rom[_pos+7] = "e";
    msg_rom[_pos+8] = ":";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "P";
    msg_rom[_pos+11] = "l";
    msg_rom[_pos+12] = "a";
    msg_rom[_pos+13] = "c";
    msg_rom[_pos+14] = "e";
    msg_rom[_pos+15] = " ";
    msg_rom[_pos+16] = "f";
    msg_rom[_pos+17] = "i";
    msg_rom[_pos+18] = "n";
    msg_rom[_pos+19] = "g";
    msg_rom[_pos+20] = "e";
    msg_rom[_pos+21] = "r";
    msg_rom[_pos+22] = ".";
    msg_rom[_pos+23] = ".";
    msg_rom[_pos+24] = ".";
    msg_rom[_pos+25] = 8'h0D;
    msg_rom[_pos+26] = 8'h0A;
    _pos = _pos + 9'd27;
    // MSG_ACCT_INFO (22B)
    msg_base[9] = _pos;
    msg_len[9]  = 7'd22;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "A";
    msg_rom[_pos+3] = "c";
    msg_rom[_pos+4] = "c";
    msg_rom[_pos+5] = "o";
    msg_rom[_pos+6] = "u";
    msg_rom[_pos+7] = "n";
    msg_rom[_pos+8] = "t";
    msg_rom[_pos+9] = ":";
    msg_rom[_pos+10] = " ";
    msg_rom[_pos+11] = "U";
    msg_rom[_pos+12] = "s";
    msg_rom[_pos+13] = "e";
    msg_rom[_pos+14] = "r";
    msg_rom[_pos+15] = 8'h0D;
    msg_rom[_pos+16] = 8'h0A;
    msg_rom[_pos+17] = "B";
    msg_rom[_pos+18] = "a";
    msg_rom[_pos+19] = "l";
    msg_rom[_pos+20] = ":";
    msg_rom[_pos+21] = " ";
    _pos = _pos + 9'd22;
    // MSG_DELETED (12B)
    msg_base[10] = _pos;
    msg_len[10]  = 7'd12;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "D";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "l";
    msg_rom[_pos+5] = "e";
    msg_rom[_pos+6] = "t";
    msg_rom[_pos+7] = "e";
    msg_rom[_pos+8] = "d";
    msg_rom[_pos+9] = ".";
    msg_rom[_pos+10] = 8'h0D;
    msg_rom[_pos+11] = 8'h0A;
    _pos = _pos + 9'd12;
    // MSG_RECHARGE_1 (29B)
    msg_base[11] = _pos;
    msg_len[11]  = 7'd29;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "R";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "c";
    msg_rom[_pos+5] = "h";
    msg_rom[_pos+6] = "a";
    msg_rom[_pos+7] = "r";
    msg_rom[_pos+8] = "g";
    msg_rom[_pos+9] = "e";
    msg_rom[_pos+10] = ":";
    msg_rom[_pos+11] = " ";
    msg_rom[_pos+12] = "P";
    msg_rom[_pos+13] = "l";
    msg_rom[_pos+14] = "a";
    msg_rom[_pos+15] = "c";
    msg_rom[_pos+16] = "e";
    msg_rom[_pos+17] = " ";
    msg_rom[_pos+18] = "f";
    msg_rom[_pos+19] = "i";
    msg_rom[_pos+20] = "n";
    msg_rom[_pos+21] = "g";
    msg_rom[_pos+22] = "e";
    msg_rom[_pos+23] = "r";
    msg_rom[_pos+24] = ".";
    msg_rom[_pos+25] = ".";
    msg_rom[_pos+26] = ".";
    msg_rom[_pos+27] = 8'h0D;
    msg_rom[_pos+28] = 8'h0A;
    _pos = _pos + 9'd29;
    // MSG_CUR_BAL (15B)
    msg_base[12] = _pos;
    msg_len[12]  = 7'd15;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "C";
    msg_rom[_pos+3] = "u";
    msg_rom[_pos+4] = "r";
    msg_rom[_pos+5] = "r";
    msg_rom[_pos+6] = "e";
    msg_rom[_pos+7] = "n";
    msg_rom[_pos+8] = "t";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "b";
    msg_rom[_pos+11] = "a";
    msg_rom[_pos+12] = "l";
    msg_rom[_pos+13] = ":";
    msg_rom[_pos+14] = " ";
    _pos = _pos + 9'd15;
    // MSG_QUERY_1 (26B)
    msg_base[13] = _pos;
    msg_len[13]  = 7'd26;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "Q";
    msg_rom[_pos+3] = "u";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = "r";
    msg_rom[_pos+6] = "y";
    msg_rom[_pos+7] = ":";
    msg_rom[_pos+8] = " ";
    msg_rom[_pos+9] = "P";
    msg_rom[_pos+10] = "l";
    msg_rom[_pos+11] = "a";
    msg_rom[_pos+12] = "c";
    msg_rom[_pos+13] = "e";
    msg_rom[_pos+14] = " ";
    msg_rom[_pos+15] = "f";
    msg_rom[_pos+16] = "i";
    msg_rom[_pos+17] = "n";
    msg_rom[_pos+18] = "g";
    msg_rom[_pos+19] = "e";
    msg_rom[_pos+20] = "r";
    msg_rom[_pos+21] = ".";
    msg_rom[_pos+22] = ".";
    msg_rom[_pos+23] = ".";
    msg_rom[_pos+24] = 8'h0D;
    msg_rom[_pos+25] = 8'h0A;
    _pos = _pos + 9'd26;
    // MSG_PAY_AMOUNT (32B)
    msg_base[14] = _pos;
    msg_len[14]  = 7'd32;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "P";
    msg_rom[_pos+3] = "A";
    msg_rom[_pos+4] = "Y";
    msg_rom[_pos+5] = "M";
    msg_rom[_pos+6] = "E";
    msg_rom[_pos+7] = "N";
    msg_rom[_pos+8] = "T";
    msg_rom[_pos+9] = 8'h0D;
    msg_rom[_pos+10] = 8'h0A;
    msg_rom[_pos+11] = "E";
    msg_rom[_pos+12] = "n";
    msg_rom[_pos+13] = "t";
    msg_rom[_pos+14] = "e";
    msg_rom[_pos+15] = "r";
    msg_rom[_pos+16] = " ";
    msg_rom[_pos+17] = "a";
    msg_rom[_pos+18] = "m";
    msg_rom[_pos+19] = "o";
    msg_rom[_pos+20] = "u";
    msg_rom[_pos+21] = "n";
    msg_rom[_pos+22] = "t";
    msg_rom[_pos+23] = " ";
    msg_rom[_pos+24] = "(";
    msg_rom[_pos+25] = "y";
    msg_rom[_pos+26] = "u";
    msg_rom[_pos+27] = "a";
    msg_rom[_pos+28] = "n";
    msg_rom[_pos+29] = ")";
    msg_rom[_pos+30] = ":";
    msg_rom[_pos+31] = " ";
    _pos = _pos + 9'd32;
    // MSG_PAY_CONFIRM (30B)
    msg_base[15] = _pos;
    msg_len[15]  = 7'd30;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "P";
    msg_rom[_pos+3] = "l";
    msg_rom[_pos+4] = "a";
    msg_rom[_pos+5] = "c";
    msg_rom[_pos+6] = "e";
    msg_rom[_pos+7] = " ";
    msg_rom[_pos+8] = "f";
    msg_rom[_pos+9] = "i";
    msg_rom[_pos+10] = "n";
    msg_rom[_pos+11] = "g";
    msg_rom[_pos+12] = "e";
    msg_rom[_pos+13] = "r";
    msg_rom[_pos+14] = " ";
    msg_rom[_pos+15] = "t";
    msg_rom[_pos+16] = "o";
    msg_rom[_pos+17] = " ";
    msg_rom[_pos+18] = "c";
    msg_rom[_pos+19] = "o";
    msg_rom[_pos+20] = "n";
    msg_rom[_pos+21] = "f";
    msg_rom[_pos+22] = "i";
    msg_rom[_pos+23] = "r";
    msg_rom[_pos+24] = "m";
    msg_rom[_pos+25] = ".";
    msg_rom[_pos+26] = ".";
    msg_rom[_pos+27] = ".";
    msg_rom[_pos+28] = 8'h0D;
    msg_rom[_pos+29] = 8'h0A;
    _pos = _pos + 9'd30;
    // MSG_INSUFF (25B)
    msg_base[16] = _pos;
    msg_len[16]  = 7'd25;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "I";
    msg_rom[_pos+3] = "n";
    msg_rom[_pos+4] = "s";
    msg_rom[_pos+5] = "u";
    msg_rom[_pos+6] = "f";
    msg_rom[_pos+7] = "f";
    msg_rom[_pos+8] = "i";
    msg_rom[_pos+9] = "c";
    msg_rom[_pos+10] = "i";
    msg_rom[_pos+11] = "e";
    msg_rom[_pos+12] = "n";
    msg_rom[_pos+13] = "t";
    msg_rom[_pos+14] = " ";
    msg_rom[_pos+15] = "b";
    msg_rom[_pos+16] = "a";
    msg_rom[_pos+17] = "l";
    msg_rom[_pos+18] = "a";
    msg_rom[_pos+19] = "n";
    msg_rom[_pos+20] = "c";
    msg_rom[_pos+21] = "e";
    msg_rom[_pos+22] = "!";
    msg_rom[_pos+23] = 8'h0D;
    msg_rom[_pos+24] = 8'h0A;
    _pos = _pos + 9'd25;
    // MSG_NO_MATCH (13B)
    msg_base[17] = _pos;
    msg_len[17]  = 7'd13;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "N";
    msg_rom[_pos+3] = "o";
    msg_rom[_pos+4] = " ";
    msg_rom[_pos+5] = "m";
    msg_rom[_pos+6] = "a";
    msg_rom[_pos+7] = "t";
    msg_rom[_pos+8] = "c";
    msg_rom[_pos+9] = "h";
    msg_rom[_pos+10] = "!";
    msg_rom[_pos+11] = 8'h0D;
    msg_rom[_pos+12] = 8'h0A;
    _pos = _pos + 9'd13;
    // MSG_CANCELLED (14B)
    msg_base[18] = _pos;
    msg_len[18]  = 7'd14;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "C";
    msg_rom[_pos+3] = "a";
    msg_rom[_pos+4] = "n";
    msg_rom[_pos+5] = "c";
    msg_rom[_pos+6] = "e";
    msg_rom[_pos+7] = "l";
    msg_rom[_pos+8] = "l";
    msg_rom[_pos+9] = "e";
    msg_rom[_pos+10] = "d";
    msg_rom[_pos+11] = ".";
    msg_rom[_pos+12] = 8'h0D;
    msg_rom[_pos+13] = 8'h0A;
    _pos = _pos + 9'd14;
    // MSG_ENROLL_FAIL (18B)
    msg_base[19] = _pos;
    msg_len[19]  = 7'd18;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "E";
    msg_rom[_pos+3] = "n";
    msg_rom[_pos+4] = "r";
    msg_rom[_pos+5] = "o";
    msg_rom[_pos+6] = "l";
    msg_rom[_pos+7] = "l";
    msg_rom[_pos+8] = " ";
    msg_rom[_pos+9] = "f";
    msg_rom[_pos+10] = "a";
    msg_rom[_pos+11] = "i";
    msg_rom[_pos+12] = "l";
    msg_rom[_pos+13] = "e";
    msg_rom[_pos+14] = "d";
    msg_rom[_pos+15] = "!";
    msg_rom[_pos+16] = 8'h0D;
    msg_rom[_pos+17] = 8'h0A;
    _pos = _pos + 9'd18;
    // MSG_ANY_KEY (20B)
    msg_base[20] = _pos;
    msg_len[20]  = 7'd20;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "P";
    msg_rom[_pos+3] = "r";
    msg_rom[_pos+4] = "e";
    msg_rom[_pos+5] = "s";
    msg_rom[_pos+6] = "s";
    msg_rom[_pos+7] = " ";
    msg_rom[_pos+8] = "a";
    msg_rom[_pos+9] = "n";
    msg_rom[_pos+10] = "y";
    msg_rom[_pos+11] = " ";
    msg_rom[_pos+12] = "k";
    msg_rom[_pos+13] = "e";
    msg_rom[_pos+14] = "y";
    msg_rom[_pos+15] = ".";
    msg_rom[_pos+16] = ".";
    msg_rom[_pos+17] = ".";
    msg_rom[_pos+18] = 8'h0D;
    msg_rom[_pos+19] = 8'h0A;
    _pos = _pos + 9'd20;
    // MSG_NEW_BAL (11B)
    msg_base[21] = _pos;
    msg_len[21]  = 7'd11;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "N";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "w";
    msg_rom[_pos+5] = " ";
    msg_rom[_pos+6] = "b";
    msg_rom[_pos+7] = "a";
    msg_rom[_pos+8] = "l";
    msg_rom[_pos+9] = ":";
    msg_rom[_pos+10] = " ";
    _pos = _pos + 9'd11;
    // MSG_ACCT_ID (14B)
    msg_base[22] = _pos;
    msg_len[22]  = 7'd14;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "A";
    msg_rom[_pos+3] = "c";
    msg_rom[_pos+4] = "c";
    msg_rom[_pos+5] = "o";
    msg_rom[_pos+6] = "u";
    msg_rom[_pos+7] = "n";
    msg_rom[_pos+8] = "t";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "I";
    msg_rom[_pos+11] = "D";
    msg_rom[_pos+12] = ":";
    msg_rom[_pos+13] = " ";
    _pos = _pos + 9'd14;
    // MSG_PAID (8B)
    msg_base[23] = _pos;
    msg_len[23]  = 7'd8;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "P";
    msg_rom[_pos+3] = "a";
    msg_rom[_pos+4] = "i";
    msg_rom[_pos+5] = "d";
    msg_rom[_pos+6] = ":";
    msg_rom[_pos+7] = " ";
    _pos = _pos + 9'd8;
    // MSG_BAL_AFTER (11B)
    msg_base[24] = _pos;
    msg_len[24]  = 7'd11;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "B";
    msg_rom[_pos+3] = "a";
    msg_rom[_pos+4] = "l";
    msg_rom[_pos+5] = "a";
    msg_rom[_pos+6] = "n";
    msg_rom[_pos+7] = "c";
    msg_rom[_pos+8] = "e";
    msg_rom[_pos+9] = ":";
    msg_rom[_pos+10] = " ";
    _pos = _pos + 9'd11;
    // MSG_RECHG_AMT (21B)
    msg_base[25] = _pos;
    msg_len[25]  = 7'd21;
    msg_rom[_pos+0] = "E";
    msg_rom[_pos+1] = "n";
    msg_rom[_pos+2] = "t";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "r";
    msg_rom[_pos+5] = " ";
    msg_rom[_pos+6] = "a";
    msg_rom[_pos+7] = "m";
    msg_rom[_pos+8] = "o";
    msg_rom[_pos+9] = "u";
    msg_rom[_pos+10] = "n";
    msg_rom[_pos+11] = "t";
    msg_rom[_pos+12] = " ";
    msg_rom[_pos+13] = "(";
    msg_rom[_pos+14] = "y";
    msg_rom[_pos+15] = "u";
    msg_rom[_pos+16] = "a";
    msg_rom[_pos+17] = "n";
    msg_rom[_pos+18] = ")";
    msg_rom[_pos+19] = ":";
    msg_rom[_pos+20] = " ";
    _pos = _pos + 9'd21;
    // MSG_CONFIRM_DEL (30B)
    msg_base[26] = _pos;
    msg_len[26]  = 7'd30;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "A";
    msg_rom[_pos+3] = ":";
    msg_rom[_pos+4] = "C";
    msg_rom[_pos+5] = "o";
    msg_rom[_pos+6] = "n";
    msg_rom[_pos+7] = "f";
    msg_rom[_pos+8] = "i";
    msg_rom[_pos+9] = "r";
    msg_rom[_pos+10] = "m";
    msg_rom[_pos+11] = " ";
    msg_rom[_pos+12] = "d";
    msg_rom[_pos+13] = "e";
    msg_rom[_pos+14] = "l";
    msg_rom[_pos+15] = "e";
    msg_rom[_pos+16] = "t";
    msg_rom[_pos+17] = "e";
    msg_rom[_pos+18] = " ";
    msg_rom[_pos+19] = " ";
    msg_rom[_pos+20] = "B";
    msg_rom[_pos+21] = ":";
    msg_rom[_pos+22] = "C";
    msg_rom[_pos+23] = "a";
    msg_rom[_pos+24] = "n";
    msg_rom[_pos+25] = "c";
    msg_rom[_pos+26] = "e";
    msg_rom[_pos+27] = "l";
    msg_rom[_pos+28] = 8'h0D;
    msg_rom[_pos+29] = 8'h0A;
    _pos = _pos + 9'd30;
    // MSG_CREATED_OK (20B)
    msg_base[27] = _pos;
    msg_len[27]  = 7'd20;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "A";
    msg_rom[_pos+3] = "c";
    msg_rom[_pos+4] = "c";
    msg_rom[_pos+5] = "o";
    msg_rom[_pos+6] = "u";
    msg_rom[_pos+7] = "n";
    msg_rom[_pos+8] = "t";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "c";
    msg_rom[_pos+11] = "r";
    msg_rom[_pos+12] = "e";
    msg_rom[_pos+13] = "a";
    msg_rom[_pos+14] = "t";
    msg_rom[_pos+15] = "e";
    msg_rom[_pos+16] = "d";
    msg_rom[_pos+17] = "!";
    msg_rom[_pos+18] = 8'h0D;
    msg_rom[_pos+19] = 8'h0A;
    _pos = _pos + 9'd20;
    // MSG_RECHARGED_OK (14B)
    msg_base[28] = _pos;
    msg_len[28]  = 7'd14;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "R";
    msg_rom[_pos+3] = "e";
    msg_rom[_pos+4] = "c";
    msg_rom[_pos+5] = "h";
    msg_rom[_pos+6] = "a";
    msg_rom[_pos+7] = "r";
    msg_rom[_pos+8] = "g";
    msg_rom[_pos+9] = "e";
    msg_rom[_pos+10] = "d";
    msg_rom[_pos+11] = "!";
    msg_rom[_pos+12] = 8'h0D;
    msg_rom[_pos+13] = 8'h0A;
    _pos = _pos + 9'd14;
    // MSG_PAY_OK (23B)
    msg_base[29] = _pos;
    msg_len[29]  = 7'd23;
    msg_rom[_pos+0] = 8'h0D;
    msg_rom[_pos+1] = 8'h0A;
    msg_rom[_pos+2] = "P";
    msg_rom[_pos+3] = "a";
    msg_rom[_pos+4] = "y";
    msg_rom[_pos+5] = "m";
    msg_rom[_pos+6] = "e";
    msg_rom[_pos+7] = "n";
    msg_rom[_pos+8] = "t";
    msg_rom[_pos+9] = " ";
    msg_rom[_pos+10] = "s";
    msg_rom[_pos+11] = "u";
    msg_rom[_pos+12] = "c";
    msg_rom[_pos+13] = "c";
    msg_rom[_pos+14] = "e";
    msg_rom[_pos+15] = "s";
    msg_rom[_pos+16] = "s";
    msg_rom[_pos+17] = "f";
    msg_rom[_pos+18] = "u";
    msg_rom[_pos+19] = "l";
    msg_rom[_pos+20] = "!";
    msg_rom[_pos+21] = 8'h0D;
    msg_rom[_pos+22] = 8'h0A;
    _pos = _pos + 9'd23;
end

    // ============================================
    // Sender FSM (shared by all states)
    // ============================================
    localparam TX_IDLE = 2'd0, TX_SEND = 2'd1, TX_DONE = 2'd2;
    reg [1:0]  tx_state;
    reg [4:0]  mid;   // message ID register
    reg [6:0]  mdx;   // message index
    reg        mgo;   // trigger
    reg        tx_busy_d;

    always @(posedge clk_100mhz) tx_busy_d <= uart_tx_busy;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            tx_state   <= TX_IDLE;
            mdx        <= 0;
            uart_tx_start <= 0;
        end else begin
            uart_tx_start <= 0;
            case (tx_state)
                TX_IDLE: begin
                    mdx <= 0;
                    if (mgo) tx_state <= TX_SEND;
                end
                TX_SEND: begin
                    if (uart_tx_busy && !tx_busy_d) begin
                        // UART has latched the current character
                        if (mdx < msg_len[mid])
                            mdx <= mdx + 1'b1;
                        else begin
                            tx_state <= TX_IDLE;
                            mdx <= 0;
                        end
                    end else if (!uart_tx_busy) begin
                        uart_tx_start <= 1;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase
        end
    end

    assign uart_tx_data = msg_rom[msg_base[mid] + {3'd0, mdx}];

    // ============================================
    // FP command helper
    // ============================================
    localparam F_IDLE = 2'd0, F_WAIT = 2'd1;
    reg [1:0]  fst;
    reg        fgo;
    reg [7:0]  fop;
    reg [15:0] fpar;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            fst          <= F_IDLE;
            fp_cmd_start <= 0;
            fp_cmd_opcode <= 0;
            fp_cmd_param  <= 0;
        end else begin
            fp_cmd_start <= 0;
            case (fst)
                F_IDLE: begin
                    if (fgo) begin
                        fp_cmd_opcode <= fop;
                        fp_cmd_param  <= fpar;
                        fp_cmd_start  <= 1;
                        fst <= F_WAIT;
                    end
                end
                F_WAIT: begin
                    if (fp_cmd_done) fst <= F_IDLE;
                end
                default: fst <= F_IDLE;
            endcase
        end
    end

    // ============================================
    // Key code to ASCII
    // ============================================
    function [7:0] k2a;
        input [3:0] k;
        case (k)
            4'd0:  k2a = "0";
            4'd1:  k2a = "1";
            4'd2:  k2a = "2";
            4'd3:  k2a = "3";
            4'd4:  k2a = "4";
            4'd5:  k2a = "5";
            4'd6:  k2a = "6";
            4'd7:  k2a = "7";
            4'd8:  k2a = "8";
            4'd9:  k2a = "9";
            4'd10: k2a = "A";
            4'd11: k2a = "B";
            4'd12: k2a = "C";
            4'd13: k2a = "D";
            4'd15: k2a = "F";
            default: k2a = "?";
        endcase
    endfunction

    // ============================================
    // Find account slot by fp_id
    // ============================================
    reg [1:0]  fslot;
    reg        ffound;
    integer    _si;
    always @(*) begin
        ffound = 0;
        fslot  = 0;
        for (_si = 0; _si < MAX_ACCT; _si = _si + 1) begin
            if (acct_active[_si] && acct_fp_id[_si] == matched_fp_id) begin
                ffound = 1;
                fslot  = _si[1:0];
            end
        end
    end

    // ============================================
    // MAIN STATE MACHINE
    // ============================================
    localparam
        S_INIT       = 7'd0,
        S_INIT_FP    = 7'd1,
        S_FP_WAIT    = 7'd2,
        S_MSG_WAIT   = 7'd3,
        S_MAIN_MENU  = 7'd4,
        S_MAIN_WAIT  = 7'd5,
        S_ACCT_MENU  = 7'd6,
        S_ACCT_WAIT  = 7'd7,
        S_CR_C1      = 7'd8,
        S_CR_C1W     = 7'd9,
        S_CR_G1      = 7'd10,
        S_CR_G1W     = 7'd11,
        S_CR_C2      = 7'd12,
        S_CR_C2W     = 7'd13,
        S_CR_G2      = 7'd14,
        S_CR_G2W     = 7'd15,
        S_CR_REG     = 7'd16,
        S_CR_REGW    = 7'd17,
        S_CR_ST      = 7'd18,
        S_CR_STW     = 7'd19,
        S_CR_AMT     = 7'd20,
        S_CR_DONE    = 7'd21,
        S_DL_CAP     = 7'd22,
        S_DL_CAPW    = 7'd23,
        S_DL_GEN     = 7'd24,
        S_DL_GENW    = 7'd25,
        S_DL_SRCH    = 7'd26,
        S_DL_SRCHW   = 7'd27,
        S_DL_CONF    = 7'd28,
        S_DL_DO      = 7'd29,
        S_DL_DOW     = 7'd30,
        S_DL_RES     = 7'd31,
        S_RC_CAP     = 7'd32,
        S_RC_CAPW    = 7'd33,
        S_RC_GEN     = 7'd34,
        S_RC_GENW    = 7'd35,
        S_RC_SRCH    = 7'd36,
        S_RC_SRCHW   = 7'd37,
        S_RC_AMT     = 7'd38,
        S_RC_DONE    = 7'd39,
        S_QR_CAP     = 7'd40,
        S_QR_CAPW    = 7'd41,
        S_QR_GEN     = 7'd42,
        S_QR_GENW    = 7'd43,
        S_QR_SRCH    = 7'd44,
        S_QR_SRCHW   = 7'd45,
        S_QR_DONE    = 7'd46,
        S_PY_AMT     = 7'd47,
        S_PY_CAP     = 7'd48,
        S_PY_CAPW    = 7'd49,
        S_PY_GEN     = 7'd50,
        S_PY_GENW    = 7'd51,
        S_PY_SRCH    = 7'd52,
        S_PY_SRCHW   = 7'd53,
        S_PY_DONE    = 7'd54,
        S_SHOW_KEY   = 7'd55;

    reg [6:0]  st, st_ret;
    reg [31:0] inp;           // numeric input accumulator (yuan)
    reg [15:0] fpr;           // saved FP response
    reg        echo_key;      // flag: echo key press to UART

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            st            <= S_INIT;
            st_ret        <= 0;
            inp           <= 0;
            matched_fp_id <= 0;
            fpr           <= 0;
            echo_key      <= 0;
        end else begin
            // Default: all control signals low
            mgo     <= 0;
            fgo     <= 0;
            fop     <= 0;
            fpar    <= 0;
            beep_short <= 0;
            beep_ok    <= 0;
            beep_fail  <= 0;

            case (st)
                S_INIT: begin
                    mid   <= MSG_TITLE;
                    mgo   <= 1;
                    st    <= S_MSG_WAIT;
                    st_ret <= S_INIT_FP;
                end

                S_INIT_FP: begin
                    fop  <= FP_READ_PARAM;
                    fpar <= 0;
                    fgo  <= 1;
                    st   <= S_FP_WAIT;
                    st_ret <= S_MAIN_MENU;
                end

                // ---- Generic wait states ----
                S_MSG_WAIT: if (tx_state == TX_IDLE) st <= st_ret;

                S_FP_WAIT: begin
                    if (fp_cmd_done) begin
                        fpr <= fp_response;
                        if (st_ret == S_MAIN_MENU) begin
                            mid   <= (fp_status == 8'd2) ? MSG_FP_OK : MSG_FP_FAIL;
                            mgo   <= 1;
                            st    <= S_MSG_WAIT;
                            st_ret <= S_MAIN_MENU;
                        end else begin
                            st <= st_ret;
                        end
                    end
                end

                // ---- Main Menu ----
                S_MAIN_MENU: begin
                    mid   <= MSG_MAIN_MENU;
                    mgo   <= 1;
                    st    <= S_MSG_WAIT;
                    st_ret <= S_MAIN_WAIT;
                end

                S_MAIN_WAIT: begin
                    if (kb_valid) begin
                        beep_short <= 1;
                        case (kb_code)
                            4'd1: begin
                                st <= S_ACCT_MENU;
                            end
                            4'd2: begin
                                inp  <= 0;
                                mid  <= MSG_PAY_AMOUNT;
                                mgo  <= 1;
                                st   <= S_MSG_WAIT;
                                st_ret <= S_PY_AMT;
                            end
                            default: st <= S_MAIN_WAIT;
                        endcase
                    end
                end

                // ---- Account Menu ----
                S_ACCT_MENU: begin
                    mid   <= MSG_ACCT_MENU;
                    mgo   <= 1;
                    st    <= S_MSG_WAIT;
                    st_ret <= S_ACCT_WAIT;
                end

                S_ACCT_WAIT: begin
                    if (kb_valid) begin
                        beep_short <= 1;
                        case (kb_code)
                            4'd1: begin
                                mid   <= MSG_CREATE_1;
                                mgo   <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_CR_C1;
                            end
                            4'd2: begin
                                mid   <= MSG_DELETE_1;
                                mgo   <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_DL_CAP;
                            end
                            4'd3: begin
                                mid   <= MSG_RECHARGE_1;
                                mgo   <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_RC_CAP;
                            end
                            4'd4: begin
                                mid   <= MSG_QUERY_1;
                                mgo   <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_QR_CAP;
                            end
                            4'd11: st <= S_MAIN_MENU;  // B=back
                            default: st <= S_ACCT_WAIT;
                        endcase
                    end
                end

                // ---- Create Account ----
                // C1: GET_IMAGE
                S_CR_C1:  begin fop<=FP_GET_IMAGE; fpar<=0; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_C1W; end
                S_CR_C1W: begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                              begin st<=S_CR_G1; end
                end
                // G1: GEN_CHAR(1)
                S_CR_G1:  begin fop<=FP_GEN_CHAR; fpar<=16'd1; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_G1W; end
                S_CR_G1W: begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                              begin mid<=MSG_CREATE_2; mgo<=1; st<=S_MSG_WAIT; st_ret<=S_CR_C2; end
                end
                // C2: wait for A, then GET_IMAGE
                S_CR_C2: begin
                    if (kb_valid && kb_code == 4'd10) begin
                        fop<=FP_GET_IMAGE; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_C2W;
                    end
                end
                S_CR_C2W: begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                              begin st<=S_CR_G2; end
                end
                // G2: GEN_CHAR(2)
                S_CR_G2:  begin fop<=FP_GEN_CHAR; fpar<=16'd2; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_G2W; end
                S_CR_G2W: begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                              begin st<=S_CR_REG; end
                end
                // REG_MODEL + STORE
                S_CR_REG:  begin fop<=FP_REG_MODEL; fpar<=0; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_REGW; end
                S_CR_REGW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                              begin st<=S_CR_ST; end
                end
                S_CR_ST:   begin fop<=FP_STORE; fpar<={{8'd0}, next_fp_id}; fgo<=1; st<=S_FP_WAIT; st_ret<=S_CR_STW; end
                S_CR_STW:  begin
                    if (fp_status != 8'd2) begin mid<=MSG_ENROLL_FAIL; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else begin
                        mid   <= MSG_ENTER_DEP;
                        mgo   <= 1;
                        inp   <= 0;
                        st    <= S_MSG_WAIT;
                        st_ret <= S_CR_AMT;
                    end
                end
                // Enter deposit amount
                S_CR_AMT: begin
                    if (kb_valid) begin
                        beep_short <= 1;
                        case (kb_code)
                            4'd10: begin
                                if (inp > 0) begin
                                    // Save account
                                    acct_balance[next_fp_id - 8'd1] <= inp * 32'd100;
                                end
                                acct_active[next_fp_id - 8'd1]  <= 1;
                                acct_fp_id[next_fp_id - 8'd1]   <= next_fp_id;
                                next_fp_id <= next_fp_id + 8'd1;
                                mid   <= MSG_CREATED_OK;
                                mgo   <= 1;
                                beep_ok <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_SHOW_KEY;
                            end
                            4'd11: begin mid<=MSG_CANCELLED; mgo<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                            4'd15: inp <= inp / 10;
                            default: if (kb_code <= 4'd9 && inp < 32'd99999) inp <= inp * 32'd10 + {28'd0, kb_code};
                        endcase
                    end
                end

                // ---- Delete Account ----
                S_DL_CAP:  begin fop<=FP_GET_IMAGE; fgo<=1; st<=S_FP_WAIT; st_ret<=S_DL_CAPW; end
                S_DL_CAPW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                               begin st<=S_DL_GEN; end
                end
                S_DL_GEN:  begin fop<=FP_GEN_CHAR; fpar<=16'd1; fgo<=1; st<=S_FP_WAIT; st_ret<=S_DL_GENW; end
                S_DL_GENW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else                               begin st<=S_DL_SRCH; end
                end
                S_DL_SRCH: begin fop<=FP_SEARCH; fpar<={8'd1, MAX_FP_ID}; fgo<=1; st<=S_FP_WAIT; st_ret<=S_DL_SRCHW; end
                S_DL_SRCHW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else begin
                        matched_fp_id <= fp_response[7:0];
                        mid   <= MSG_ACCT_INFO;
                        mgo   <= 1;
                        st    <= S_MSG_WAIT;
                        st_ret <= S_DL_CONF;
                    end
                end
                S_DL_CONF: begin mid<=MSG_CONFIRM_DEL; mgo<=1; st<=S_MSG_WAIT; st_ret<=S_DL_DO; end
                S_DL_DO: begin
                    if (kb_valid) begin
                        case (kb_code)
                            4'd10: begin
                                fop <= FP_DELETE;
                                fpar <= {8'd0, matched_fp_id};
                                fgo <= 1;
                                st <= S_FP_WAIT;
                                st_ret <= S_DL_DOW;
                            end
                            4'd11: begin mid<=MSG_CANCELLED; mgo<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                            default: st <= S_DL_DO;
                        endcase
                    end
                end
                S_DL_DOW: begin
                    acct_active[fslot]  <= 0;
                    acct_fp_id[fslot]   <= 0;
                    acct_balance[fslot] <= 0;
                    mid   <= MSG_DELETED;
                    mgo   <= 1;
                    beep_ok <= 1;
                    st    <= S_MSG_WAIT;
                    st_ret <= S_SHOW_KEY;
                end

                // ---- Recharge ----
                S_RC_CAP:   begin fop<=FP_GET_IMAGE; fgo<=1; st<=S_FP_WAIT; st_ret<=S_RC_CAPW; end
                S_RC_CAPW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_RC_GEN; end
                S_RC_GEN:   begin fop<=FP_GEN_CHAR; fpar<=16'd1; fgo<=1; st<=S_FP_WAIT; st_ret<=S_RC_GENW; end
                S_RC_GENW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_RC_SRCH; end
                S_RC_SRCH:  begin fop<=FP_SEARCH; fpar<={8'd1, MAX_FP_ID}; fgo<=1; st<=S_FP_WAIT; st_ret<=S_RC_SRCHW; end
                S_RC_SRCHW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else begin
                        matched_fp_id <= fp_response[7:0];
                        mid   <= MSG_CUR_BAL;
                        mgo   <= 1;
                        inp   <= 0;
                        st    <= S_MSG_WAIT;
                        st_ret <= S_RC_AMT;
                    end
                end
                S_RC_AMT: begin
                    if (kb_valid) begin
                        beep_short <= 1;
                        case (kb_code)
                            4'd10: begin
                                if (inp > 0 && ffound)
                                    acct_balance[fslot] <= acct_balance[fslot] + inp * 32'd100;
                                mid  <= MSG_RECHARGED_OK;
                                mgo  <= 1;
                                beep_ok <= 1;
                                st    <= S_MSG_WAIT;
                                st_ret <= S_SHOW_KEY;
                            end
                            4'd11: begin mid<=MSG_CANCELLED; mgo<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                            4'd15: inp <= inp / 10;
                            default: if (kb_code <= 4'd9 && inp < 32'd99999) inp <= inp * 32'd10 + {28'd0, kb_code};
                        endcase
                    end
                end

                // ---- Query ----
                S_QR_CAP:   begin fop<=FP_GET_IMAGE; fgo<=1; st<=S_FP_WAIT; st_ret<=S_QR_CAPW; end
                S_QR_CAPW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_QR_GEN; end
                S_QR_GEN:   begin fop<=FP_GEN_CHAR; fpar<=16'd1; fgo<=1; st<=S_FP_WAIT; st_ret<=S_QR_GENW; end
                S_QR_GENW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_QR_SRCH; end
                S_QR_SRCH:  begin fop<=FP_SEARCH; fpar<={8'd1, MAX_FP_ID}; fgo<=1; st<=S_FP_WAIT; st_ret<=S_QR_SRCHW; end
                S_QR_SRCHW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else begin
                        matched_fp_id <= fp_response[7:0];
                        mid  <= MSG_ACCT_INFO;
                        mgo  <= 1;
                        beep_ok <= 1;
                        st   <= S_MSG_WAIT;
                        st_ret <= S_QR_DONE;
                    end
                end
                S_QR_DONE: begin
                    // Auto-advance after showing account info
                    if (tx_state == TX_IDLE) begin
                        mid  <= MSG_CUR_BAL;
                        mgo  <= 1;
                        st   <= S_MSG_WAIT;
                        st_ret <= S_SHOW_KEY;
                    end
                end

                // ---- Payment ----
                S_PY_AMT: begin
                    if (kb_valid) begin
                        beep_short <= 1;
                        case (kb_code)
                            4'd10: begin
                                if (inp > 0) begin
                                    mid  <= MSG_PAY_CONFIRM;
                                    mgo  <= 1;
                                    st   <= S_MSG_WAIT;
                                    st_ret <= S_PY_CAP;
                                end
                            end
                            4'd11: st <= S_MAIN_MENU;
                            4'd15: inp <= inp / 10;
                            default: if (kb_code <= 4'd9 && inp < 32'd99999) inp <= inp * 32'd10 + {28'd0, kb_code};
                        endcase
                    end
                end
                S_PY_CAP:   begin fop<=FP_GET_IMAGE; fgo<=1; st<=S_FP_WAIT; st_ret<=S_PY_CAPW; end
                S_PY_CAPW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_PY_GEN; end
                S_PY_GEN:   begin fop<=FP_GEN_CHAR; fpar<=16'd1; fgo<=1; st<=S_FP_WAIT; st_ret<=S_PY_GENW; end
                S_PY_GENW:  begin if (fp_status!=8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end else st<=S_PY_SRCH; end
                S_PY_SRCH:  begin fop<=FP_SEARCH; fpar<={8'd1, MAX_FP_ID}; fgo<=1; st<=S_FP_WAIT; st_ret<=S_PY_SRCHW; end
                S_PY_SRCHW: begin
                    if (fp_status != 8'd2) begin mid<=MSG_NO_MATCH; mgo<=1; beep_fail<=1; st<=S_MSG_WAIT; st_ret<=S_SHOW_KEY; end
                    else begin
                        matched_fp_id <= fp_response[7:0];
                        if (ffound) begin
                            if (acct_balance[fslot] >= inp * 32'd100) begin
                                acct_balance[fslot] <= acct_balance[fslot] - inp * 32'd100;
                                mid   <= MSG_PAY_OK;
                                beep_ok <= 1;
                            end else begin
                                mid   <= MSG_INSUFF;
                                beep_fail <= 1;
                            end
                        end else begin
                            mid   <= MSG_NO_MATCH;
                            beep_fail <= 1;
                        end
                        mgo <= 1;
                        st  <= S_MSG_WAIT;
                        st_ret <= S_SHOW_KEY;
                    end
                end

                // ---- Show "press any key" then return to main ----
                S_SHOW_KEY: begin
                    mid  <= MSG_ANY_KEY;
                    mgo  <= 1;
                    st   <= S_MSG_WAIT;
                    st_ret <= S_MAIN_MENU;
                end

                default: st <= S_INIT;
            endcase
        end
    end

endmodule
