// VGA Timing Controller — 640x480 @ 60Hz
// Pixel clock: 25 MHz (must be provided externally via MMCM/PLL)
`timescale 1ns / 1ps

module vga_ctrl (
    input  wire       clk,       // 25 MHz pixel clock
    input  wire       rst_n,
    output reg        hsync,
    output reg        vsync,
    output reg  [9:0] pixel_x,
    output reg  [9:0] pixel_y,
    output reg        video_active
);

    localparam H_ACTIVE = 640;
    localparam H_FRONT  = 16;
    localparam H_SYNC   = 96;
    localparam H_BACK   = 48;
    localparam H_TOTAL  = 800;

    localparam V_ACTIVE = 480;
    localparam V_FRONT  = 10;
    localparam V_SYNC   = 2;
    localparam V_BACK   = 33;
    localparam V_TOTAL  = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync        <= 1'b1;
            vsync        <= 1'b1;
            pixel_x      <= 10'd0;
            pixel_y      <= 10'd0;
            video_active <= 1'b0;
        end else begin
            hsync        <= ~(h_cnt >= H_ACTIVE + H_FRONT && h_cnt < H_ACTIVE + H_FRONT + H_SYNC);
            vsync        <= ~(v_cnt >= V_ACTIVE + V_FRONT && v_cnt < V_ACTIVE + V_FRONT + V_SYNC);
            video_active <= (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);
            pixel_x      <= h_cnt;
            pixel_y      <= v_cnt;
        end
    end

endmodule
