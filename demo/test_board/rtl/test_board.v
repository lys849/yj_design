// test_board.v — Nexys4 DDR Board Self-Test
// Tests on-board LEDs, USB-UART, and BTNC button
// No external peripherals required
`timescale 1ns / 1ps

module test_board (
    input  wire       clk_100mhz,
    input  wire       rst_n,          // CPU_RESET, active low
    input  wire       btnc,           // center button, active high
    output wire       debug_tx,       // UART TX → FT2232 → PC
    output wire [3:0] led             // test LEDs (active high)
);

    // ============================================
    // LED tick: ~2 Hz (100MHz / 50,000,000)
    // ============================================
    localparam LED_MAX = 50_000_000;
    reg [25:0] led_cnt;
    wire led_tick = (led_cnt == LED_MAX - 1);

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n)
            led_cnt <= 0;
        else if (led_tick)
            led_cnt <= 0;
        else
            led_cnt <= led_cnt + 1'b1;
    end

    // ============================================
    // BTNC debounce (~20ms @ 100MHz = 2,000,000)
    // ============================================
    localparam DB_MAX = 2_000_000;
    reg [20:0] db_cnt;
    reg [2:0]  btnc_sync;
    reg        btnc_stable, btnc_prev;

    always @(posedge clk_100mhz)
        btnc_sync <= {btnc_sync[1:0], btnc};

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt      <= 0;
            btnc_stable <= 0;
            btnc_prev   <= 0;
        end else begin
            if (btnc_sync[2] != btnc_stable) begin
                if (db_cnt >= DB_MAX) begin
                    btnc_stable <= btnc_sync[2];
                    db_cnt      <= 0;
                end else begin
                    db_cnt <= db_cnt + 1'b1;
                end
            end else begin
                db_cnt <= 0;
            end
            btnc_prev <= btnc_stable;
        end
    end

    wire btnc_pressed = btnc_stable && !btnc_prev;

    // ============================================
    // LED patterns
    //   0 = walk-left  (1→2→4→8→1...)
    //   1 = walk-right (8→4→2→1→8...)
    //   2 = all-blink  (on/off toggle)
    //   3 = binary-counter (0→1→2→...→15)
    // ============================================
    reg [1:0] pattern;
    reg [3:0] led_reg;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            pattern <= 2'd0;
            led_reg <= 4'b0001;
        end else if (btnc_pressed) begin
            pattern <= pattern + 2'd1;
            case (pattern + 2'd1)
                2'd0: led_reg <= 4'b0001;
                2'd1: led_reg <= 4'b0001;
                2'd2: led_reg <= 4'b1111;
                2'd3: led_reg <= 4'b0000;
                default: led_reg <= 4'b0001;
            endcase
        end else if (led_tick) begin
            case (pattern)
                2'd0: led_reg <= {led_reg[2:0], led_reg[3]};   // walk left
                2'd1: led_reg <= {led_reg[0], led_reg[3:1]};   // walk right
                2'd2: led_reg <= ~led_reg;                      // all-blink
                2'd3: led_reg <= led_reg + 4'd1;                // binary-counter
            endcase
        end
    end

    assign led = led_reg;

    // ============================================
    // UART TX (115200 baud @ 100MHz)
    // ============================================
    wire [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy, tx_done;

    uart_tx #(.CLK_FREQ(100_000_000), .BAUD_RATE(32'd115200))
        u_uart_tx (
            .clk     (clk_100mhz),
            .rst_n   (rst_n),
            .tx_data (tx_data),
            .tx_start(tx_start),
            .tx      (debug_tx),
            .tx_busy (tx_busy),
            .tx_done (tx_done)
        );

    // ============================================
    // Message ROM (initialised for synthesis with Vivado)
    //   msg_hello[0:18] = "Nexys4 DDR Test OK!\r\n" (19 chars)
    //   msg_btn[0:16]   = "BTNC pressed!\r\n"      (15 chars)
    // ============================================
    localparam HELLO_LEN = 21;
    localparam BTN_LEN   = 15;

    reg [7:0] msg_rom [0:35];
    initial begin
        // Hello message
        msg_rom[0]  = "N";
        msg_rom[1]  = "e";
        msg_rom[2]  = "x";
        msg_rom[3]  = "y";
        msg_rom[4]  = "s";
        msg_rom[5]  = "4";
        msg_rom[6]  = " ";
        msg_rom[7]  = "D";
        msg_rom[8]  = "D";
        msg_rom[9]  = "R";
        msg_rom[10] = " ";
        msg_rom[11] = "T";
        msg_rom[12] = "e";
        msg_rom[13] = "s";
        msg_rom[14] = "t";
        msg_rom[15] = " ";
        msg_rom[16] = "O";
        msg_rom[17] = "K";
        msg_rom[18] = "!";
        msg_rom[19] = 8'h0D;   // \r
        msg_rom[20] = 8'h0A;   // \n
        // BTN message (at offset 21)
        msg_rom[21] = "B";
        msg_rom[22] = "T";
        msg_rom[23] = "N";
        msg_rom[24] = "C";
        msg_rom[25] = " ";
        msg_rom[26] = "p";
        msg_rom[27] = "r";
        msg_rom[28] = "e";
        msg_rom[29] = "s";
        msg_rom[30] = "s";
        msg_rom[31] = "e";
        msg_rom[32] = "d";
        msg_rom[33] = "!";
        msg_rom[34] = 8'h0D;   // \r
        msg_rom[35] = 8'h0A;   // \n
    end

    // ============================================
    // UART TX sender state machine
    //   Waits ~3s then sends hello, repeats every ~3s
    //   BTNC press → immediately sends BTN message
    // ============================================
    localparam S_IDLE   = 3'd0;
    localparam S_SEND   = 3'd1;
    localparam S_WAIT   = 3'd2;
    localparam S_BTN    = 3'd3;
    localparam S_BTNSND = 3'd4;

    localparam WAIT_CYCLES = 300_000_000 - 1;  // ~3s

    reg [28:0] wait_cntr;
    reg [2:0]  state;
    reg [4:0]  char_idx;
    reg        send_pending;  // tx_start asserted, waiting for uart to latch
    reg        tx_busy_d;     // delayed tx_busy for edge detection

    always @(posedge clk_100mhz) tx_busy_d <= tx_busy;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            char_idx   <= 0;
            wait_cntr  <= 0;
            tx_start   <= 0;
            send_pending <= 0;
        end else begin
            tx_start <= 0;

            case (state)
                S_IDLE: begin
                    state      <= S_SEND;
                    char_idx   <= 0;
                    send_pending <= 0;
                end

                S_SEND: begin
                    if (!send_pending && !tx_busy) begin
                        tx_start     <= 1;
                        send_pending <= 1;
                    end else if (tx_busy && !tx_busy_d) begin
                        send_pending <= 0;
                        if (char_idx + 1'b1 < HELLO_LEN) begin
                            char_idx <= char_idx + 1'b1;
                        end else begin
                            char_idx  <= 0;
                            state     <= S_WAIT;
                            wait_cntr <= 0;
                        end
                    end
                end

                S_WAIT: begin
                    if (btnc_pressed) begin
                        state    <= S_BTN;
                        char_idx <= 0;
                        send_pending <= 0;
                    end else if (wait_cntr < WAIT_CYCLES) begin
                        wait_cntr <= wait_cntr + 1'b1;
                    end else begin
                        state    <= S_SEND;
                        char_idx <= 0;
                        send_pending <= 0;
                    end
                end

                S_BTN: begin
                    if (!send_pending && !tx_busy) begin
                        tx_start     <= 1;
                        send_pending <= 1;
                    end else if (tx_busy && !tx_busy_d) begin
                        send_pending <= 0;
                        if (char_idx + 1'b1 < BTN_LEN) begin
                            char_idx <= char_idx + 1'b1;
                        end else begin
                            char_idx  <= 0;
                            state     <= S_WAIT;
                            wait_cntr <= 0;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Mux message character to UART data
    reg [4:0] rom_addr;
    always @(*) begin
        case (state)
            S_SEND, S_IDLE:  rom_addr = char_idx;
            S_BTN:            rom_addr = char_idx + 21;
            default:          rom_addr = 0;
        endcase
    end

    assign tx_data = msg_rom[rom_addr];

endmodule
