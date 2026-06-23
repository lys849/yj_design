// Complete fingerprint payment system top for Nexys4 DDR.
// MicroBlaze/AXI lives in system_bd_wrapper; this top adds VGA pixel timing.
`timescale 1ns / 1ps

module fp_payment_system_top (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output wire       debug_tx,
    input  wire       debug_rx,
    output wire [3:0] kb_row,
    input  wire [3:0] kb_col,
    input  wire       btnc,
    input  wire       btnd,
    output wire       fp_sensor_tx,
    input  wire       fp_sensor_rx,
    output wire       buzzer,
    output wire [3:0] led,
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b
);

    wire [10:0] vga_char_addr_cpu;
    wire [7:0]  vga_char_data_cpu;
    wire        vga_char_we_toggle_cpu;

    system_bd_wrapper u_bd (
        .sys_clock(clk_100mhz),
        .reset_n(rst_n),
        .uart_tx(debug_tx),
        .uart_rx(debug_rx),
        .kb_row(kb_row),
        .kb_col(kb_col),
        .btnc(btnc),
        .btnd(btnd),
        .fp_sensor_tx(fp_sensor_tx),
        .fp_sensor_rx(fp_sensor_rx),
        .buzzer_out(buzzer),
        .led(led),
        .vga_char_addr(vga_char_addr_cpu),
        .vga_char_data(vga_char_data_cpu),
        .vga_char_we_toggle(vga_char_we_toggle_cpu)
    );

    wire clk_25m_unbuf;
    wire clk_25m;
    wire clkfb;
    wire mmcm_locked;
    wire vga_rst_n = rst_n & mmcm_locked;

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(40.0),
        .CLKIN1_PERIOD(10.0)
    ) u_vga_mmcm (
        .CLKOUT0(clk_25m_unbuf),
        .CLKFBOUT(clkfb),
        .LOCKED(mmcm_locked),
        .CLKIN1(clk_100mhz),
        .CLKFBIN(clkfb),
        .PWRDWN(1'b0),
        .RST(~rst_n)
    );

    BUFG u_vga_bufg (.I(clk_25m_unbuf), .O(clk_25m));

    reg [2:0]  vga_we_sync;
    reg [10:0] vga_char_addr_pix;
    reg [7:0]  vga_char_data_pix;
    reg        vga_char_we_pix;

    always @(posedge clk_25m or negedge vga_rst_n) begin
        if (!vga_rst_n) begin
            vga_we_sync      <= 3'b000;
            vga_char_addr_pix <= 11'd0;
            vga_char_data_pix <= 8'h20;
            vga_char_we_pix   <= 1'b0;
        end else begin
            vga_we_sync <= {vga_we_sync[1:0], vga_char_we_toggle_cpu};
            vga_char_we_pix <= vga_we_sync[2] ^ vga_we_sync[1];
            if (vga_we_sync[2] ^ vga_we_sync[1]) begin
                vga_char_addr_pix <= vga_char_addr_cpu;
                vga_char_data_pix <= vga_char_data_cpu;
            end
        end
    end

    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       video_active;

    vga_ctrl u_vga_ctrl (
        .clk(clk_25m),
        .rst_n(vga_rst_n),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_active(video_active)
    );

    vga_text u_vga_text (
        .clk(clk_25m),
        .rst_n(vga_rst_n),
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .char_addr(vga_char_addr_pix),
        .char_data(vga_char_data_pix),
        .char_we(vga_char_we_pix),
        .pixel_r(vga_r),
        .pixel_g(vga_g),
        .pixel_b(vga_b)
    );

endmodule
