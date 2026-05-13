// Top-level integration - Fingerprint Payment System
// Integrates all peripheral controllers for MicroBlaze soft processor
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
    wire        flash_wr_en, flash_rd_en, flash_busy, flash_done;
    wire [23:0] flash_addr;
    wire [7:0]  flash_wr_data, flash_rd_data;

    spi_flash flash_inst (
        .clk(clk_50mhz), .rst_n(sys_rst_n),
        .spi_cs_n(flash_cs_n), .spi_clk(flash_clk),
        .spi_mosi(flash_mosi), .spi_miso(flash_miso),
        .wr_en(flash_wr_en), .rd_en(flash_rd_en),
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

    // Generate fingerprint command start pulse
    wire fp_cmd_start_pulse;
    assign fp_cmd_start_pulse = reg_fingerprint_cmd[31] && !fp_cmd_start_d;

    // Assign CPU-register-driven signals to modules
    assign fp_cmd_opcode = reg_fingerprint_cmd[23:16];
    assign fp_cmd_param  = reg_fingerprint_cmd[15:0];
    assign fp_cmd_start  = fp_cmd_start_pulse;

    assign flash_wr_en   = reg_flash_cmd[0];
    assign flash_rd_en   = reg_flash_cmd[1];
    assign flash_addr    = reg_flash_addr[23:0];
    assign flash_wr_data = reg_flash_wr_data[7:0];

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
        end else begin
            fp_cmd_start_d <= reg_fingerprint_cmd[31];
            reg_fingerprint_resp <= {8'd0, fp_status, 8'd0, fp_response};
            reg_flash_rd_data    <= {24'd0, flash_rd_data};
            if (kb_key_valid)
                reg_keyboard <= {28'd0, 1'b1, kb_key_code};
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
