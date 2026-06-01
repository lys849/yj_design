// Top-level integration - Fingerprint Payment System
// Integrates all peripheral controllers for MicroBlaze soft processor
//
// Fixes:
//   B5: reg_keyboard valid bit now auto-clears after KEY_HOLD_CYCLES,
//       preventing infinite wait in C code.
//   B7: reg_flash_cmd bits auto-clear on flash_done, so storage_wait_ready
//       can detect completion. Flash busy/done exposed in reg_flash_rd_data.
//   Register layout: fp_response now stored correctly as full 16-bit value.
//   Added flash_erase_en signal for separate erase command.
`timescale 1ns / 1ps

module top (
    input  wire         clk_100mhz,
    input  wire         rst_n,
    output wire         fp_sensor_tx,
    input  wire         fp_sensor_rx,
    output wire         vga_hsync,
    output wire         vga_vsync,
    output wire [3:0]   vga_r,
    output wire [3:0]   vga_g,
    output wire [3:0]   vga_b,
    output wire [3:0]   kb_row,
    input  wire [3:0]   kb_col,
    output wire         buzzer,
    output wire         flash_cs_n,
    output wire         flash_clk,
    output wire         flash_mosi,
    input  wire         flash_miso,
    output reg  [3:0]   led,
    output wire         debug_tx,     // FPGA → FT2232 → PC (D4)
    input  wire         debug_rx      // FPGA ← FT2232 ← PC (C4)
);

    // ============================================
    // Clock and reset
    // ============================================
    wire clk_25mhz, clk_50mhz, clk_locked, sys_rst_n;
    assign sys_rst_n = rst_n & clk_locked;

    clk_gen clk_gen_inst (
        .clk_100mhz(clk_100mhz), .rst_n(rst_n),
        .clk_25mhz(clk_25mhz), .clk_50mhz(clk_50mhz), .locked(clk_locked)
    );

    // ============================================
    // VGA signals
    // ============================================
    wire [9:0]  vga_px, vga_py;
    wire        vga_active;
    wire [10:0] char_wr_addr;
    wire [7:0]  char_wr_data;
    wire        char_wr_en;

    vga_ctrl vga_ctrl_inst (
        .clk(clk_25mhz), .rst_n(sys_rst_n),
        .hsync(vga_hsync), .vsync(vga_vsync),
        .pixel_x(vga_px), .pixel_y(vga_py), .video_active(vga_active)
    );

    vga_text vga_text_inst (
        .clk(clk_25mhz), .rst_n(sys_rst_n),
        .video_active(vga_active), .pixel_x(vga_px), .pixel_y(vga_py),
        .char_addr(char_wr_addr), .char_data(char_wr_data), .char_we(char_wr_en),
        .pixel_r(vga_r), .pixel_g(vga_g), .pixel_b(vga_b)
    );

    // ============================================
    // Fingerprint sensor signals
    // ============================================
    wire [7:0]  fp_cmd_opcode, fp_status;
    wire [15:0] fp_cmd_param, fp_response;
    wire        fp_cmd_start, fp_cmd_done;

    fingerprint_ctrl fp_ctrl_inst (
        .clk(clk_50mhz), .rst_n(sys_rst_n),
        .sensor_tx(fp_sensor_tx), .sensor_rx(fp_sensor_rx),
        .cmd_opcode(fp_cmd_opcode), .cmd_param(fp_cmd_param),
        .cmd_start(fp_cmd_start), .response(fp_response),
        .status(fp_status), .cmd_done(fp_cmd_done)
    );

    // ============================================
    // Keyboard signals
    // ============================================
    wire [3:0] kb_key_code;
    wire       kb_key_valid;

    keyboard_scan kb_inst (
        .clk(clk_50mhz), .rst_n(sys_rst_n),
        .row(kb_row), .col(kb_col),
        .key_code(kb_key_code), .key_valid(kb_key_valid)
    );

    // ============================================
    // Buzzer signals
    // ============================================
    wire beep_short, beep_ok, beep_fail;

    buzzer_ctrl buzzer_inst (
        .clk(clk_50mhz), .rst_n(sys_rst_n),
        .beep_short(beep_short), .beep_ok(beep_ok), .beep_fail(beep_fail),
        .buzzer_out(buzzer)
    );

    // ============================================
    // SPI Flash signals
    // ============================================
    wire        flash_wr_en, flash_rd_en, flash_erase_en;
    wire        flash_busy, flash_done;
    wire [23:0] flash_addr;
    wire [7:0]  flash_wr_data, flash_rd_data;

    spi_flash flash_inst (
        .clk(clk_50mhz), .rst_n(sys_rst_n),
        .spi_cs_n(flash_cs_n), .spi_clk(flash_clk),
        .spi_mosi(flash_mosi), .spi_miso(flash_miso),
        .wr_en(flash_wr_en), .rd_en(flash_rd_en), .erase_en(flash_erase_en),
        .addr(flash_addr), .wr_data(flash_wr_data),
        .rd_data(flash_rd_data), .busy(flash_busy), .done(flash_done)
    );

    // ============================================
    // Register file for CPU access (simplified AXI-like interface)
    // ============================================
    reg [31:0] reg_fingerprint_cmd;
    reg [31:0] reg_fingerprint_resp;
    reg [31:0] reg_keyboard;
    reg [31:0] reg_buzzer_ctrl;
    reg [31:0] reg_flash_cmd;
    reg [31:0] reg_flash_addr;
    reg [31:0] reg_flash_wr_data;
    reg [31:0] reg_flash_rd_data;
    reg [31:0] reg_vga_char;
    reg [31:0] reg_led;

    reg        fp_cmd_start_d;

    // FIXED B5: auto-clear keyboard valid bit counter
    reg [15:0] key_hold_cnt;
    localparam KEY_HOLD_CYCLES = 50000;  // hold key valid for ~1ms

    // FIXED B7: track previous flash_done to auto-clear cmd bits
    reg flash_done_d;

    // Generate fingerprint command start pulse
    wire fp_cmd_start_pulse;
    assign fp_cmd_start_pulse = reg_fingerprint_cmd[31] && !fp_cmd_start_d;

    // Assign CPU-register-driven signals to modules
    assign fp_cmd_opcode = reg_fingerprint_cmd[23:16];
    assign fp_cmd_param  = reg_fingerprint_cmd[15:0];
    assign fp_cmd_start  = fp_cmd_start_pulse;

    // FIXED B6: flash_erase_en mapped to bit 2 of command register
    assign flash_wr_en    = reg_flash_cmd[0];
    assign flash_rd_en    = reg_flash_cmd[1];
    assign flash_erase_en = reg_flash_cmd[2];
    assign flash_addr     = reg_flash_addr[23:0];
    assign flash_wr_data  = reg_flash_wr_data[7:0];

    assign beep_short = reg_buzzer_ctrl[0];
    assign beep_ok    = reg_buzzer_ctrl[1];
    assign beep_fail  = reg_buzzer_ctrl[2];

    assign char_wr_addr = reg_vga_char[22:12];
    assign char_wr_data = reg_vga_char[7:0];
    assign char_wr_en   = reg_vga_char[31];

    // Register update logic
    always @(posedge clk_50mhz or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            fp_cmd_start_d       <= 1'b0;
            reg_fingerprint_resp <= 32'd0;
            reg_flash_rd_data    <= 32'd0;
            reg_keyboard         <= 32'd0;
            key_hold_cnt         <= 16'd0;
            flash_done_d         <= 1'b0;
        end else begin
            fp_cmd_start_d <= reg_fingerprint_cmd[31];

            // ── Fingerprint response register ──────────────────
            // FIXED layout: {fp_status[7:0], 8'd0, fp_response[15:0]}
            // bits 31:24 = fp_status
            // bits 23:16 = 0 (reserved)
            // bits 15:0  = fp_response (16-bit parameter from sensor)
            reg_fingerprint_resp <= {fp_status, 8'd0, fp_response};

            // ── Flash read data + status register ──────────────
            // FIXED B7: expose busy/done in upper bits for software polling
            // bits 7:0   = flash_rd_data
            // bit  8     = flash_busy
            // bit  9     = flash_done
            // bits 31:10 = 0
            reg_flash_rd_data <= {22'd0, flash_done, flash_busy, flash_rd_data};

            // ── FIXED B7: auto-clear flash cmd bits when done ──
            flash_done_d <= flash_done;
            if (flash_done && !flash_done_d)
                reg_flash_cmd <= 32'd0;    // clear all command bits

            // ── FIXED B5: keyboard with auto-clear ─────────────
            if (kb_key_valid) begin
                reg_keyboard <= {28'd0, 1'b1, kb_key_code};
                key_hold_cnt <= 16'd0;
            end else if (key_hold_cnt < KEY_HOLD_CYCLES) begin
                key_hold_cnt <= key_hold_cnt + 16'd1;
                // keep reg_keyboard valid
            end else begin
                // Auto-clear valid bit after hold time
                reg_keyboard[4] <= 1'b0;
            end
        end
    end

    // LED driver
    always @(posedge clk_50mhz or negedge sys_rst_n) begin
        if (!sys_rst_n)
            led <= 4'b0000;
        else
            led <= reg_led[3:0];
    end

    // Debug UART — loopback for basic echo test
    // For real use: instantiate a UART transmitter (e.g., uart_tx) here
    assign debug_tx = debug_rx;

endmodule

// ============================================
// Simple Clock Generator (for simulation)
// ============================================
module clk_gen (
    input  wire clk_100mhz,
    input  wire rst_n,
    output reg  clk_25mhz,
    output reg  clk_50mhz,
    output reg  locked
);
    reg [1:0] div25_cnt;
    reg       div50_toggle;
    reg [7:0] lock_cnt;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            div25_cnt   <= 2'd0;
            div50_toggle <= 1'b0;
            clk_25mhz   <= 1'b0;
            clk_50mhz   <= 1'b0;
            lock_cnt    <= 8'd0;
            locked      <= 1'b0;
        end else begin
            div25_cnt <= div25_cnt + 2'd1;
            if (div25_cnt == 2'd1 || div25_cnt == 2'd3)
                clk_25mhz <= ~clk_25mhz;

            div50_toggle <= ~div50_toggle;
            clk_50mhz <= div50_toggle;

            if (lock_cnt < 8'd255)
                lock_cnt <= lock_cnt + 8'd1;
            else
                locked <= 1'b1;
        end
    end
endmodule
