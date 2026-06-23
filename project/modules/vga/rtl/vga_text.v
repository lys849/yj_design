// VGA Text Renderer — 80 columns x 30 rows, 8x16 pixel font
// Character buffer: BRAM inferred via initial block (no reset loop)
// Single clock domain (25 MHz pixel clock)
// Write interface synchronized externally when crossing clock domains
`timescale 1ns / 1ps

module vga_text (
    input  wire        clk,           // 25 MHz pixel clock
    input  wire        rst_n,
    input  wire        video_active,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,
    input  wire [10:0] char_addr,     // 0-2399 (80*30)
    input  wire [7:0]  char_data,
    input  wire        char_we,
    output reg  [3:0]  pixel_r,
    output reg  [3:0]  pixel_g,
    output reg  [3:0]  pixel_b
);

    localparam COLS = 80;
    localparam ROWS = 30;

    reg [7:0] char_ram [0:2399];

    integer init_i;
    initial for (init_i = 0; init_i < 2400; init_i = init_i + 1)
        char_ram[init_i] = 8'h20;

    always @(posedge clk)
        if (char_we) char_ram[char_addr] <= char_data;

    reg [6:0] col_idx;
    reg [4:0] row_idx;
    reg [2:0] pix_x_off;
    reg [3:0] pix_y_off;
    reg [7:0] cur_char;
    reg [7:0] font_line;
    reg       pixel_on;
    reg       active_d1, active_d2;

    wire [6:0] next_col = pixel_x[9:3];
    wire [4:0] next_row = pixel_y[9:4];
    wire [10:0] rd_addr  = next_row * COLS + next_col;

    always @(posedge clk) begin
        cur_char  <= char_ram[rd_addr];
        pix_x_off <= pixel_x[2:0];
        pix_y_off <= pixel_y[3:0];
        active_d1 <= video_active;
    end

    wire [7:0] font_pixels;
    font_rom u_font (
        .char_code(cur_char[6:0]),
        .row(pix_y_off),
        .pixels(font_pixels)
    );

    always @(posedge clk) begin
        pixel_on  <= font_pixels[7 - pix_x_off];
        active_d2 <= active_d1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_r <= 4'd0;
            pixel_g <= 4'd0;
            pixel_b <= 4'd0;
        end else if (active_d2) begin
            if (pixel_on) begin
                pixel_r <= 4'hF;
                pixel_g <= 4'hF;
                pixel_b <= 4'hF;
            end else begin
                pixel_r <= 4'h0;
                pixel_g <= 4'h0;
                pixel_b <= 4'h1;
            end
        end else begin
            pixel_r <= 4'd0;
            pixel_g <= 4'd0;
            pixel_b <= 4'd0;
        end
    end

endmodule

// 8x16 Font ROM — combinational lookup
// Covers ASCII 0x20-0x7E (space through tilde)
module font_rom (
    input  wire [6:0] char_code,
    input  wire [3:0] row,
    output reg  [7:0] pixels
);

    reg [7:0] font_data [0:1535]; // 96 chars * 16 rows

    integer fi;
    initial begin
        for (fi = 0; fi < 1536; fi = fi + 1) font_data[fi] = 8'h00;

        // Space (0x20) — all zeros, already done

        // '0' (0x30)
        font_data[('h30-'h20)*16+ 2] = 8'b00111100;
        font_data[('h30-'h20)*16+ 3] = 8'b01100110;
        font_data[('h30-'h20)*16+ 4] = 8'b01100110;
        font_data[('h30-'h20)*16+ 5] = 8'b01101110;
        font_data[('h30-'h20)*16+ 6] = 8'b01110110;
        font_data[('h30-'h20)*16+ 7] = 8'b01100110;
        font_data[('h30-'h20)*16+ 8] = 8'b01100110;
        font_data[('h30-'h20)*16+ 9] = 8'b00111100;

        // '1' (0x31)
        font_data[('h31-'h20)*16+ 2] = 8'b00011000;
        font_data[('h31-'h20)*16+ 3] = 8'b00111000;
        font_data[('h31-'h20)*16+ 4] = 8'b00011000;
        font_data[('h31-'h20)*16+ 5] = 8'b00011000;
        font_data[('h31-'h20)*16+ 6] = 8'b00011000;
        font_data[('h31-'h20)*16+ 7] = 8'b00011000;
        font_data[('h31-'h20)*16+ 8] = 8'b00011000;
        font_data[('h31-'h20)*16+ 9] = 8'b01111110;

        // '2' (0x32)
        font_data[('h32-'h20)*16+ 2] = 8'b00111100;
        font_data[('h32-'h20)*16+ 3] = 8'b01100110;
        font_data[('h32-'h20)*16+ 4] = 8'b00000110;
        font_data[('h32-'h20)*16+ 5] = 8'b00001100;
        font_data[('h32-'h20)*16+ 6] = 8'b00011000;
        font_data[('h32-'h20)*16+ 7] = 8'b00110000;
        font_data[('h32-'h20)*16+ 8] = 8'b01100000;
        font_data[('h32-'h20)*16+ 9] = 8'b01111110;

        // '3' (0x33)
        font_data[('h33-'h20)*16+ 2] = 8'b00111100;
        font_data[('h33-'h20)*16+ 3] = 8'b01100110;
        font_data[('h33-'h20)*16+ 4] = 8'b00000110;
        font_data[('h33-'h20)*16+ 5] = 8'b00011100;
        font_data[('h33-'h20)*16+ 6] = 8'b00000110;
        font_data[('h33-'h20)*16+ 7] = 8'b00000110;
        font_data[('h33-'h20)*16+ 8] = 8'b01100110;
        font_data[('h33-'h20)*16+ 9] = 8'b00111100;

        // '4' (0x34)
        font_data[('h34-'h20)*16+ 2] = 8'b00001100;
        font_data[('h34-'h20)*16+ 3] = 8'b00011100;
        font_data[('h34-'h20)*16+ 4] = 8'b00101100;
        font_data[('h34-'h20)*16+ 5] = 8'b01001100;
        font_data[('h34-'h20)*16+ 6] = 8'b01111110;
        font_data[('h34-'h20)*16+ 7] = 8'b00001100;
        font_data[('h34-'h20)*16+ 8] = 8'b00001100;
        font_data[('h34-'h20)*16+ 9] = 8'b00001100;

        // '5' (0x35)
        font_data[('h35-'h20)*16+ 2] = 8'b01111110;
        font_data[('h35-'h20)*16+ 3] = 8'b01100000;
        font_data[('h35-'h20)*16+ 4] = 8'b01100000;
        font_data[('h35-'h20)*16+ 5] = 8'b01111100;
        font_data[('h35-'h20)*16+ 6] = 8'b00000110;
        font_data[('h35-'h20)*16+ 7] = 8'b00000110;
        font_data[('h35-'h20)*16+ 8] = 8'b01100110;
        font_data[('h35-'h20)*16+ 9] = 8'b00111100;

        // '6' (0x36)
        font_data[('h36-'h20)*16+ 2] = 8'b00111100;
        font_data[('h36-'h20)*16+ 3] = 8'b01100110;
        font_data[('h36-'h20)*16+ 4] = 8'b01100000;
        font_data[('h36-'h20)*16+ 5] = 8'b01111100;
        font_data[('h36-'h20)*16+ 6] = 8'b01100110;
        font_data[('h36-'h20)*16+ 7] = 8'b01100110;
        font_data[('h36-'h20)*16+ 8] = 8'b01100110;
        font_data[('h36-'h20)*16+ 9] = 8'b00111100;

        // '7' (0x37)
        font_data[('h37-'h20)*16+ 2] = 8'b01111110;
        font_data[('h37-'h20)*16+ 3] = 8'b00000110;
        font_data[('h37-'h20)*16+ 4] = 8'b00001100;
        font_data[('h37-'h20)*16+ 5] = 8'b00011000;
        font_data[('h37-'h20)*16+ 6] = 8'b00011000;
        font_data[('h37-'h20)*16+ 7] = 8'b00011000;
        font_data[('h37-'h20)*16+ 8] = 8'b00011000;
        font_data[('h37-'h20)*16+ 9] = 8'b00011000;

        // '8' (0x38)
        font_data[('h38-'h20)*16+ 2] = 8'b00111100;
        font_data[('h38-'h20)*16+ 3] = 8'b01100110;
        font_data[('h38-'h20)*16+ 4] = 8'b01100110;
        font_data[('h38-'h20)*16+ 5] = 8'b00111100;
        font_data[('h38-'h20)*16+ 6] = 8'b01100110;
        font_data[('h38-'h20)*16+ 7] = 8'b01100110;
        font_data[('h38-'h20)*16+ 8] = 8'b01100110;
        font_data[('h38-'h20)*16+ 9] = 8'b00111100;

        // '9' (0x39)
        font_data[('h39-'h20)*16+ 2] = 8'b00111100;
        font_data[('h39-'h20)*16+ 3] = 8'b01100110;
        font_data[('h39-'h20)*16+ 4] = 8'b01100110;
        font_data[('h39-'h20)*16+ 5] = 8'b00111110;
        font_data[('h39-'h20)*16+ 6] = 8'b00000110;
        font_data[('h39-'h20)*16+ 7] = 8'b00000110;
        font_data[('h39-'h20)*16+ 8] = 8'b01100110;
        font_data[('h39-'h20)*16+ 9] = 8'b00111100;

        // 'A' (0x41)
        font_data[('h41-'h20)*16+ 2] = 8'b00011000;
        font_data[('h41-'h20)*16+ 3] = 8'b00111100;
        font_data[('h41-'h20)*16+ 4] = 8'b01100110;
        font_data[('h41-'h20)*16+ 5] = 8'b01100110;
        font_data[('h41-'h20)*16+ 6] = 8'b01111110;
        font_data[('h41-'h20)*16+ 7] = 8'b01100110;
        font_data[('h41-'h20)*16+ 8] = 8'b01100110;
        font_data[('h41-'h20)*16+ 9] = 8'b01100110;

        // 'B' (0x42)
        font_data[('h42-'h20)*16+ 2] = 8'b01111100;
        font_data[('h42-'h20)*16+ 3] = 8'b01100110;
        font_data[('h42-'h20)*16+ 4] = 8'b01100110;
        font_data[('h42-'h20)*16+ 5] = 8'b01111100;
        font_data[('h42-'h20)*16+ 6] = 8'b01100110;
        font_data[('h42-'h20)*16+ 7] = 8'b01100110;
        font_data[('h42-'h20)*16+ 8] = 8'b01100110;
        font_data[('h42-'h20)*16+ 9] = 8'b01111100;

        // 'C' (0x43)
        font_data[('h43-'h20)*16+ 2] = 8'b00111100;
        font_data[('h43-'h20)*16+ 3] = 8'b01100110;
        font_data[('h43-'h20)*16+ 4] = 8'b01100000;
        font_data[('h43-'h20)*16+ 5] = 8'b01100000;
        font_data[('h43-'h20)*16+ 6] = 8'b01100000;
        font_data[('h43-'h20)*16+ 7] = 8'b01100000;
        font_data[('h43-'h20)*16+ 8] = 8'b01100110;
        font_data[('h43-'h20)*16+ 9] = 8'b00111100;

        // 'D' (0x44)
        font_data[('h44-'h20)*16+ 2] = 8'b01111000;
        font_data[('h44-'h20)*16+ 3] = 8'b01101100;
        font_data[('h44-'h20)*16+ 4] = 8'b01100110;
        font_data[('h44-'h20)*16+ 5] = 8'b01100110;
        font_data[('h44-'h20)*16+ 6] = 8'b01100110;
        font_data[('h44-'h20)*16+ 7] = 8'b01100110;
        font_data[('h44-'h20)*16+ 8] = 8'b01101100;
        font_data[('h44-'h20)*16+ 9] = 8'b01111000;

        // 'E' (0x45)
        font_data[('h45-'h20)*16+ 2] = 8'b01111110;
        font_data[('h45-'h20)*16+ 3] = 8'b01100000;
        font_data[('h45-'h20)*16+ 4] = 8'b01100000;
        font_data[('h45-'h20)*16+ 5] = 8'b01111100;
        font_data[('h45-'h20)*16+ 6] = 8'b01100000;
        font_data[('h45-'h20)*16+ 7] = 8'b01100000;
        font_data[('h45-'h20)*16+ 8] = 8'b01100000;
        font_data[('h45-'h20)*16+ 9] = 8'b01111110;

        // 'F' (0x46)
        font_data[('h46-'h20)*16+ 2] = 8'b01111110;
        font_data[('h46-'h20)*16+ 3] = 8'b01100000;
        font_data[('h46-'h20)*16+ 4] = 8'b01100000;
        font_data[('h46-'h20)*16+ 5] = 8'b01111100;
        font_data[('h46-'h20)*16+ 6] = 8'b01100000;
        font_data[('h46-'h20)*16+ 7] = 8'b01100000;
        font_data[('h46-'h20)*16+ 8] = 8'b01100000;
        font_data[('h46-'h20)*16+ 9] = 8'b01100000;

        // 'G' (0x47)
        font_data[('h47-'h20)*16+ 2] = 8'b00111100;
        font_data[('h47-'h20)*16+ 3] = 8'b01100110;
        font_data[('h47-'h20)*16+ 4] = 8'b01100000;
        font_data[('h47-'h20)*16+ 5] = 8'b01100000;
        font_data[('h47-'h20)*16+ 6] = 8'b01101110;
        font_data[('h47-'h20)*16+ 7] = 8'b01100110;
        font_data[('h47-'h20)*16+ 8] = 8'b01100110;
        font_data[('h47-'h20)*16+ 9] = 8'b00111110;

        // 'H' (0x48)
        font_data[('h48-'h20)*16+ 2] = 8'b01100110;
        font_data[('h48-'h20)*16+ 3] = 8'b01100110;
        font_data[('h48-'h20)*16+ 4] = 8'b01100110;
        font_data[('h48-'h20)*16+ 5] = 8'b01111110;
        font_data[('h48-'h20)*16+ 6] = 8'b01100110;
        font_data[('h48-'h20)*16+ 7] = 8'b01100110;
        font_data[('h48-'h20)*16+ 8] = 8'b01100110;
        font_data[('h48-'h20)*16+ 9] = 8'b01100110;

        // 'I' (0x49)
        font_data[('h49-'h20)*16+ 2] = 8'b00111100;
        font_data[('h49-'h20)*16+ 3] = 8'b00011000;
        font_data[('h49-'h20)*16+ 4] = 8'b00011000;
        font_data[('h49-'h20)*16+ 5] = 8'b00011000;
        font_data[('h49-'h20)*16+ 6] = 8'b00011000;
        font_data[('h49-'h20)*16+ 7] = 8'b00011000;
        font_data[('h49-'h20)*16+ 8] = 8'b00011000;
        font_data[('h49-'h20)*16+ 9] = 8'b00111100;

        // 'K' (0x4B)
        font_data[('h4B-'h20)*16+ 2] = 8'b01100110;
        font_data[('h4B-'h20)*16+ 3] = 8'b01101100;
        font_data[('h4B-'h20)*16+ 4] = 8'b01111000;
        font_data[('h4B-'h20)*16+ 5] = 8'b01110000;
        font_data[('h4B-'h20)*16+ 6] = 8'b01111000;
        font_data[('h4B-'h20)*16+ 7] = 8'b01101100;
        font_data[('h4B-'h20)*16+ 8] = 8'b01100110;
        font_data[('h4B-'h20)*16+ 9] = 8'b01100110;

        // 'L' (0x4C)
        font_data[('h4C-'h20)*16+ 2] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 3] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 4] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 5] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 6] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 7] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 8] = 8'b01100000;
        font_data[('h4C-'h20)*16+ 9] = 8'b01111110;

        // 'M' (0x4D)
        font_data[('h4D-'h20)*16+ 2] = 8'b01100011;
        font_data[('h4D-'h20)*16+ 3] = 8'b01110111;
        font_data[('h4D-'h20)*16+ 4] = 8'b01111111;
        font_data[('h4D-'h20)*16+ 5] = 8'b01101011;
        font_data[('h4D-'h20)*16+ 6] = 8'b01100011;
        font_data[('h4D-'h20)*16+ 7] = 8'b01100011;
        font_data[('h4D-'h20)*16+ 8] = 8'b01100011;
        font_data[('h4D-'h20)*16+ 9] = 8'b01100011;

        // 'N' (0x4E)
        font_data[('h4E-'h20)*16+ 2] = 8'b01100110;
        font_data[('h4E-'h20)*16+ 3] = 8'b01110110;
        font_data[('h4E-'h20)*16+ 4] = 8'b01111110;
        font_data[('h4E-'h20)*16+ 5] = 8'b01111110;
        font_data[('h4E-'h20)*16+ 6] = 8'b01101110;
        font_data[('h4E-'h20)*16+ 7] = 8'b01100110;
        font_data[('h4E-'h20)*16+ 8] = 8'b01100110;
        font_data[('h4E-'h20)*16+ 9] = 8'b01100110;

        // 'O' (0x4F)
        font_data[('h4F-'h20)*16+ 2] = 8'b00111100;
        font_data[('h4F-'h20)*16+ 3] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 4] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 5] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 6] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 7] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 8] = 8'b01100110;
        font_data[('h4F-'h20)*16+ 9] = 8'b00111100;

        // 'P' (0x50)
        font_data[('h50-'h20)*16+ 2] = 8'b01111100;
        font_data[('h50-'h20)*16+ 3] = 8'b01100110;
        font_data[('h50-'h20)*16+ 4] = 8'b01100110;
        font_data[('h50-'h20)*16+ 5] = 8'b01100110;
        font_data[('h50-'h20)*16+ 6] = 8'b01111100;
        font_data[('h50-'h20)*16+ 7] = 8'b01100000;
        font_data[('h50-'h20)*16+ 8] = 8'b01100000;
        font_data[('h50-'h20)*16+ 9] = 8'b01100000;

        // 'R' (0x52)
        font_data[('h52-'h20)*16+ 2] = 8'b01111100;
        font_data[('h52-'h20)*16+ 3] = 8'b01100110;
        font_data[('h52-'h20)*16+ 4] = 8'b01100110;
        font_data[('h52-'h20)*16+ 5] = 8'b01111100;
        font_data[('h52-'h20)*16+ 6] = 8'b01111000;
        font_data[('h52-'h20)*16+ 7] = 8'b01101100;
        font_data[('h52-'h20)*16+ 8] = 8'b01100110;
        font_data[('h52-'h20)*16+ 9] = 8'b01100110;

        // 'S' (0x53)
        font_data[('h53-'h20)*16+ 2] = 8'b00111110;
        font_data[('h53-'h20)*16+ 3] = 8'b01100000;
        font_data[('h53-'h20)*16+ 4] = 8'b01100000;
        font_data[('h53-'h20)*16+ 5] = 8'b00111100;
        font_data[('h53-'h20)*16+ 6] = 8'b00000110;
        font_data[('h53-'h20)*16+ 7] = 8'b00000110;
        font_data[('h53-'h20)*16+ 8] = 8'b00000110;
        font_data[('h53-'h20)*16+ 9] = 8'b01111100;

        // 'T' (0x54)
        font_data[('h54-'h20)*16+ 2] = 8'b01111110;
        font_data[('h54-'h20)*16+ 3] = 8'b00011000;
        font_data[('h54-'h20)*16+ 4] = 8'b00011000;
        font_data[('h54-'h20)*16+ 5] = 8'b00011000;
        font_data[('h54-'h20)*16+ 6] = 8'b00011000;
        font_data[('h54-'h20)*16+ 7] = 8'b00011000;
        font_data[('h54-'h20)*16+ 8] = 8'b00011000;
        font_data[('h54-'h20)*16+ 9] = 8'b00011000;

        // 'U' (0x55)
        font_data[('h55-'h20)*16+ 2] = 8'b01100110;
        font_data[('h55-'h20)*16+ 3] = 8'b01100110;
        font_data[('h55-'h20)*16+ 4] = 8'b01100110;
        font_data[('h55-'h20)*16+ 5] = 8'b01100110;
        font_data[('h55-'h20)*16+ 6] = 8'b01100110;
        font_data[('h55-'h20)*16+ 7] = 8'b01100110;
        font_data[('h55-'h20)*16+ 8] = 8'b01100110;
        font_data[('h55-'h20)*16+ 9] = 8'b00111100;

        // 'V' (0x56)
        font_data[('h56-'h20)*16+ 2] = 8'b01100110;
        font_data[('h56-'h20)*16+ 3] = 8'b01100110;
        font_data[('h56-'h20)*16+ 4] = 8'b01100110;
        font_data[('h56-'h20)*16+ 5] = 8'b01100110;
        font_data[('h56-'h20)*16+ 6] = 8'b01100110;
        font_data[('h56-'h20)*16+ 7] = 8'b00111100;
        font_data[('h56-'h20)*16+ 8] = 8'b00111100;
        font_data[('h56-'h20)*16+ 9] = 8'b00011000;

        // 'W' (0x57)
        font_data[('h57-'h20)*16+ 2] = 8'b01100011;
        font_data[('h57-'h20)*16+ 3] = 8'b01100011;
        font_data[('h57-'h20)*16+ 4] = 8'b01100011;
        font_data[('h57-'h20)*16+ 5] = 8'b01101011;
        font_data[('h57-'h20)*16+ 6] = 8'b01111111;
        font_data[('h57-'h20)*16+ 7] = 8'b01111111;
        font_data[('h57-'h20)*16+ 8] = 8'b01110111;
        font_data[('h57-'h20)*16+ 9] = 8'b01100011;

        // 'Y' (0x59)
        font_data[('h59-'h20)*16+ 2] = 8'b01100110;
        font_data[('h59-'h20)*16+ 3] = 8'b01100110;
        font_data[('h59-'h20)*16+ 4] = 8'b00111100;
        font_data[('h59-'h20)*16+ 5] = 8'b00011000;
        font_data[('h59-'h20)*16+ 6] = 8'b00011000;
        font_data[('h59-'h20)*16+ 7] = 8'b00011000;
        font_data[('h59-'h20)*16+ 8] = 8'b00011000;
        font_data[('h59-'h20)*16+ 9] = 8'b00011000;

        // ':' (0x3A)
        font_data[('h3A-'h20)*16+ 4] = 8'b00011000;
        font_data[('h3A-'h20)*16+ 5] = 8'b00011000;
        font_data[('h3A-'h20)*16+ 8] = 8'b00011000;
        font_data[('h3A-'h20)*16+ 9] = 8'b00011000;

        // '.' (0x2E)
        font_data[('h2E-'h20)*16+ 9] = 8'b00011000;
        font_data[('h2E-'h20)*16+10] = 8'b00011000;

        // '-' (0x2D)
        font_data[('h2D-'h20)*16+ 6] = 8'b01111110;

        // '>' (0x3E)
        font_data[('h3E-'h20)*16+ 3] = 8'b01100000;
        font_data[('h3E-'h20)*16+ 4] = 8'b00011000;
        font_data[('h3E-'h20)*16+ 5] = 8'b00000110;
        font_data[('h3E-'h20)*16+ 6] = 8'b00011000;
        font_data[('h3E-'h20)*16+ 7] = 8'b01100000;

        // '=' (0x3D)
        font_data[('h3D-'h20)*16+ 5] = 8'b01111110;
        font_data[('h3D-'h20)*16+ 7] = 8'b01111110;

        // '!' (0x21)
        font_data[('h21-'h20)*16+ 2] = 8'b00011000;
        font_data[('h21-'h20)*16+ 3] = 8'b00011000;
        font_data[('h21-'h20)*16+ 4] = 8'b00011000;
        font_data[('h21-'h20)*16+ 5] = 8'b00011000;
        font_data[('h21-'h20)*16+ 6] = 8'b00011000;
        font_data[('h21-'h20)*16+ 8] = 8'b00011000;
        font_data[('h21-'h20)*16+ 9] = 8'b00011000;
    end

    wire [10:0] addr;
    assign addr = (char_code >= 7'h20 && char_code <= 7'h7E) ?
                  (char_code - 7'h20) * 16 + {7'd0, row} : 11'd0;

    always @(*) begin
        pixels = font_data[addr];
    end

endmodule
