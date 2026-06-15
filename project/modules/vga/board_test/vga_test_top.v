// VGA Board Test — display color bars + "HELLO" text
// Uses MMCME2_BASE to generate 25 MHz pixel clock from 100 MHz input
`timescale 1ns / 1ps

module vga_test_top (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output wire       vga_hsync,
    output wire       vga_vsync,
    output wire [3:0] vga_r,
    output wire [3:0] vga_g,
    output wire [3:0] vga_b,
    output wire [3:0] led
);

    wire clk_25m, clkfb, locked;
    wire sys_rst_n = rst_n & locked;

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(40.0),
        .CLKIN1_PERIOD(10.0)
    ) mmcm_inst (
        .CLKOUT0(clk_25m_unbuf),
        .CLKFBOUT(clkfb),
        .LOCKED(locked),
        .CLKIN1(clk_100mhz),
        .CLKFBIN(clkfb),
        .PWRDWN(1'b0),
        .RST(~rst_n)
    );
    wire clk_25m_unbuf;
    BUFG bufg_25 (.I(clk_25m_unbuf), .O(clk_25m));

    wire [9:0] px, py;
    wire       active;

    vga_ctrl u_ctrl (
        .clk(clk_25m), .rst_n(sys_rst_n),
        .hsync(vga_hsync), .vsync(vga_vsync),
        .pixel_x(px), .pixel_y(py), .video_active(active)
    );

    // Write "HELLO VGA TEST" to character buffer on startup
    reg [10:0] init_addr;
    reg [7:0]  init_data;
    reg        init_we;
    reg        init_done;

    reg [7:0] msg [0:13];
    initial begin
        msg[ 0] = "H"; msg[ 1] = "E"; msg[ 2] = "L"; msg[ 3] = "L"; msg[ 4] = "O";
        msg[ 5] = " "; msg[ 6] = "V"; msg[ 7] = "G"; msg[ 8] = "A";
        msg[ 9] = " "; msg[10] = "T"; msg[11] = "E"; msg[12] = "S"; msg[13] = "T";
    end

    reg [3:0] init_idx;

    always @(posedge clk_25m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            init_addr <= 11'd0;
            init_data <= 8'h20;
            init_we   <= 1'b0;
            init_done <= 1'b0;
            init_idx  <= 4'd0;
        end else if (!init_done) begin
            if (init_idx < 4'd14) begin
                init_addr <= {7'd0, init_idx};
                init_data <= msg[init_idx];
                init_we   <= 1'b1;
                init_idx  <= init_idx + 4'd1;
            end else begin
                init_we   <= 1'b0;
                init_done <= 1'b1;
            end
        end else begin
            init_we <= 1'b0;
        end
    end

    vga_text u_text (
        .clk(clk_25m), .rst_n(sys_rst_n),
        .video_active(active), .pixel_x(px), .pixel_y(py),
        .char_addr(init_addr), .char_data(init_data), .char_we(init_we),
        .pixel_r(vga_r), .pixel_g(vga_g), .pixel_b(vga_b)
    );

    assign led = {locked, 3'b000};

endmodule
