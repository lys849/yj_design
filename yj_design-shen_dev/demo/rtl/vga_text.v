// VGA Text Renderer - draws ASCII characters on VGA display
// Uses built-in character ROM (8x16 pixel font, simplified)
// Supports 80 columns x 30 rows of text
`timescale 1ns / 1ps

module vga_text (
    input  wire         clk,          // 25 MHz pixel clock
    input  wire         rst_n,
    input  wire         video_active,
    input  wire [9:0]   pixel_x,
    input  wire [9:0]   pixel_y,
    // Character buffer interface (write from CPU)
    input  wire [10:0]  char_addr,    // 0~2399 (80*30)
    input  wire [7:0]   char_data,    // ASCII character
    input  wire         char_we,      // write enable
    output wire [3:0]   pixel_r,
    output wire [3:0]   pixel_g,
    output wire [3:0]   pixel_b
);

    // Character grid: 80 cols x 30 rows, each char is 8x16 pixels
    // Total active area: 640x480
    localparam CHAR_WIDTH  = 8;
    localparam CHAR_HEIGHT = 16;
    localparam COLS = 80;
    localparam ROWS = 30;

    // Character buffer: 80*30 = 2400 entries
    reg [7:0] char_ram [0:2399];
    reg [10:0] ram_idx;

    // Initialize display memory with menu text
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize with default menu text
            for (i = 0; i < 2400; i = i + 1) begin
                char_ram[i] <= 8'h20;  // space
            end
            // Title line
            char_ram[0]   <= "="; char_ram[1]  <= "="; char_ram[2]  <= " ";
            char_ram[3]   <= "F"; char_ram[4]  <= "P"; char_ram[5]  <= "G";
            char_ram[6]   <= "A"; char_ram[7]  <= " "; char_ram[8]  <= "P";
            char_ram[9]   <= "A"; char_ram[10] <= "Y"; char_ram[11] <= " ";
            char_ram[12]  <= "="; char_ram[13] <= "=";

            char_ram[COLS*2]   <= "1"; char_ram[COLS*2+1]  <= "."; char_ram[COLS*2+2]  <= " ";
            char_ram[COLS*2+3]  <= "A"; char_ram[COLS*2+4]  <= "c"; char_ram[COLS*2+5]  <= "c";
            char_ram[COLS*2+6]  <= "o"; char_ram[COLS*2+7]  <= "u"; char_ram[COLS*2+8]  <= "n";
            char_ram[COLS*2+9]  <= "t"; char_ram[COLS*2+10] <= " "; char_ram[COLS*2+11] <= "M";
            char_ram[COLS*2+12] <= "g"; char_ram[COLS*2+13] <= "m"; char_ram[COLS*2+14] <= "t";

            char_ram[COLS*3]   <= "2"; char_ram[COLS*3+1]  <= "."; char_ram[COLS*3+2]  <= " ";
            char_ram[COLS*3+3]  <= "P"; char_ram[COLS*3+4]  <= "a"; char_ram[COLS*3+5]  <= "y";
            char_ram[COLS*3+6]  <= "m"; char_ram[COLS*3+7]  <= "e"; char_ram[COLS*3+8]  <= "n";
            char_ram[COLS*3+9]  <= "t"; char_ram[COLS*3+10] <= " "; char_ram[COLS*3+11] <= "S";
            char_ram[COLS*3+12] <= "y"; char_ram[COLS*3+13] <= "s";

            char_ram[COLS*5]   <= "P"; char_ram[COLS*5+1]  <= "r"; char_ram[COLS*5+2]  <= "e";
            char_ram[COLS*5+3]  <= "s"; char_ram[COLS*5+4]  <= "s"; char_ram[COLS*5+5]  <= " ";
            char_ram[COLS*5+6]  <= "k"; char_ram[COLS*5+7]  <= "e"; char_ram[COLS*5+8]  <= "y";
            char_ram[COLS*5+9]  <= ":"; char_ram[COLS*5+10] <= " ";

            char_ram[COLS*7]   <= "S"; char_ram[COLS*7+1]  <= "y"; char_ram[COLS*7+2]  <= "s";
            char_ram[COLS*7+3]  <= "t"; char_ram[COLS*7+4]  <= "e"; char_ram[COLS*7+5]  <= "m";
            char_ram[COLS*7+6]  <= " "; char_ram[COLS*7+7]  <= "I"; char_ram[COLS*7+8]  <= "d";
            char_ram[COLS*7+9]  <= "l"; char_ram[COLS*7+10] <= "e";
        end else if (char_we) begin
            char_ram[char_addr] <= char_data;
        end
    end

    // Calculate character position
    wire [6:0] col = pixel_x[9:3];   // pixel_x / 8
    wire [4:0] row = pixel_y[8:4];   // pixel_y / 16
    wire [2:0] cpx = pixel_x[2:0];   // sub-pixel x position within char
    wire [3:0] cpy = pixel_y[3:0];   // sub-pixel y position within char

    // Read character from RAM
    wire [7:0] char_code;
    assign char_code = (video_active) ? char_ram[row * COLS + col] : 8'h20;

    // Simple font ROM lookup (5x8 font rendered in 8x16)
    wire font_bit;
    font_rom font_lut (
        .char_code(char_code),
        .row(cpy),
        .col(cpx),
        .pixel(font_bit)
    );

    // Output colors: white text on dark blue background, green border
    wire border = (pixel_x < 2 || pixel_x >= 638 || pixel_y < 2 || pixel_y >= 478);

    assign pixel_r = (video_active && font_bit) ? 4'hF : (border ? 4'h0 : 4'h0);
    assign pixel_g = (video_active && font_bit) ? 4'hF : (border ? 4'h3 : 4'h1);
    assign pixel_b = (video_active && font_bit) ? 4'hF : (border ? 4'h8 : 4'h4);

endmodule

// Simple ASCII font ROM - 5x7 pixel font (rendered in 8x16 space)
// Supports ASCII 0x20-0x7F
module font_rom (
    input  wire [7:0] char_code,
    input  wire [3:0] row,      // 0-15
    input  wire [2:0] col,      // 0-7
    output reg         pixel
);
    // Simplified font: only render for standard ASCII
    // Full font data would be large; use simplified lookup
    always @(*) begin
        pixel = 1'b0;
        if (col < 3'd5 && row < 4'd7) begin
            case (char_code)
                // Digits 0-9 (simple patterns)
                "0": pixel = (col == 0 || col == 4 || row == 0 || row == 6);
                "1": pixel = (col == 2 || (row == 0 && col >= 1 && col <= 2));
                "2": pixel = ((row == 0 || row == 3 || row == 6) ||
                              (row <= 3 && col == 4) || (row >= 3 && col == 0));
                "3": pixel = ((row == 0 || row == 3 || row == 6) || col == 4);
                "4": pixel = ((row <= 3 && col == 0) || col == 3 || row == 3);
                "5": pixel = ((row == 0 || row == 3 || row == 6) ||
                              (row <= 3 && col == 0) || (row >= 3 && col == 4));
                "6": pixel = ((row == 0 || row == 3 || row == 6) ||
                              (row <= 6 && col == 0) || (row >= 3 && col == 4));
                "7": pixel = (row == 0 || col == 4);
                "8": pixel = (row == 0 || row == 3 || row == 6 || col == 0 || col == 4);
                "9": pixel = ((row == 0 || row == 3 || row == 6) ||
                              (row <= 3 && col == 0) || col == 4);

                // Uppercase letters
                "A": pixel = (row == 0 || row == 3 || col == 0 || col == 4);
                "B": pixel = (row == 0 || row == 3 || row == 6 || col == 0 || col == 4);
                "C": pixel = (row == 0 || row == 6 || col == 0);
                "D": pixel = (row == 0 || row == 6 || col == 0 || col == 4);
                "E": pixel = (row == 0 || row == 3 || row == 6 || col == 0);
                "F": pixel = (row == 0 || row == 3 || col == 0);
                "G": pixel = (row == 0 || row == 6 || col == 0 ||
                             (row >= 3 && (col == 3 || col == 4)));
                "H": pixel = (row == 3 || col == 0 || col == 4);
                "I": pixel = (row == 0 || row == 6 || col == 2);
                "J": pixel = (row == 0 || col == 2 || (row >= 5 && col == 0));
                "K": pixel = (col == 0 || (row < 3 && col == 3) ||
                             (row == 3 && col == 2) || (row > 3 && col == 3));
                "L": pixel = (row == 6 || col == 0);
                "M": pixel = (col == 0 || col == 4 || (row <= 3 && col == 2));
                "N": pixel = (col == 0 || col == 4 || (row == col));
                "O": pixel = (row == 0 || row == 6 || col == 0 || col == 4);
                "P": pixel = (row == 0 || row == 3 || col == 0 ||
                             (row <= 3 && col == 4));
                "Q": pixel = (row == 0 || row == 6 || col == 0 || col == 4 ||
                             (row >= 4 && col >= 3));
                "R": pixel = (row == 0 || row == 3 || col == 0 ||
                             (row <= 3 && col == 4) || (row > 3 && col == 4));
                "S": pixel = ((row == 0 || row == 3 || row == 6) ||
                             (row <= 3 && col == 0) || (row >= 3 && col == 4));
                "T": pixel = (row == 0 || col == 2);
                "U": pixel = (row == 6 || col == 0 || col == 4);
                "V": pixel = (row <= 5 && (col == 0 || col == 4)) ||
                             (row >= 5 && (col == 1 || col == 3));
                "W": pixel = (col == 0 || col == 4 ||
                             (row >= 3 && col == 2));
                "X": pixel = (col == row || col == 4 - row);
                "Y": pixel = ((row <= 3 && (col == 0 || col == 4)) ||
                             (row >= 3 && col == 2));
                "Z": pixel = (row == 0 || row == 6 || col == (4 - row));

                // Lowercase letters
                "a": pixel = ((row == 3 || row == 6) || col == 0 || col == 4);
                "b": pixel = ((row == 0 || row == 3 || row == 6) || col == 0 || col == 4);
                "c": pixel = (row == 3 || row == 6 || col == 0);
                "d": pixel = ((row == 0 || row == 3 || row == 6) ||
                             (row <= 3 && col == 0) || col == 4);
                "e": pixel = ((row == 0 || row == 3 || row == 6) ||
                             (col == 4 && row <= 3));
                "f": pixel = (row == 0 || row == 3 || col == 0);
                "g": pixel = ((row == 3 || row == 6) || col == 0 || col == 4 ||
                             (row == 6 && col == 3));
                "h": pixel = (row == 3 || col == 0 || col == 4);
                "i": pixel = (row == 0 || row == 6 || col == 2);
                "j": pixel = (row == 0 || col == 2 || (row >= 5 && col == 0));
                "k": pixel = (col == 0 || (row <= 3 && col == 3) ||
                             (row >= 4 && col == 2));
                "l": pixel = (row == 6 || col == 2);
                "m": pixel = (row == 3 || col == 0 || col == 2 || col == 4);
                "n": pixel = (row == 3 || col == 0 || col == 4);
                "o": pixel = (row == 3 || row == 6 || col == 0 || col == 4);
                "p": pixel = (row == 3 || row == 6 || col == 0 ||
                             (row <= 3 && col == 4));
                "q": pixel = (row == 3 || row == 6 || col == 4 ||
                             (row <= 3 && col == 0));
                "r": pixel = (row == 3 || col == 0);
                "s": pixel = ((row == 0 || row == 3 || row == 6) ||
                             (row <= 3 && col == 4) || (row >= 3 && col == 0));
                "t": pixel = (row == 3 || row == 6 || col == 2);
                "u": pixel = (row == 6 || col == 0 || col == 4);
                "v": pixel = ((col == 0 || col == 4) && row <= 4) ||
                             (col == 1 || col == 3) && row >= 4;
                "w": pixel = (row >= 3 && (col == 0 || col == 2 || col == 4));
                "x": pixel = (row == 3 || col == (row - 3) || col == (4 - (row - 3)));
                "y": pixel = (row == 3 || row == 6 || col == 0 || col == 4);
                "z": pixel = (row == 0 || row == 6 || col == (4 - (row - 3)));

                // Symbols
                "=": pixel = (row == 2 || row == 4);
                "-": pixel = (row == 3);
                ".": pixel = (row == 6 && col == 2);
                ":": pixel = (row == 2 && col == 2) || (row == 5 && col == 2);
                "_": pixel = (row == 6);
                " ": pixel = 1'b0;
                "!": pixel = (col == 2 && row <= 4) || (row == 6 && col == 2);
                "+": pixel = (row == 3 || col == 2);
                "/": pixel = (col == (4 - row));
                "#": pixel = ((col == 1 || col == 3) && (row % 2 == 0)) ||
                             ((row == 1 || row == 5) && (col % 2 == 0));
                "*": pixel = (row + col == 4) || (row == col) ||
                             (row == 3 || col == 2);
                "(": pixel = (col == 2 - row || col == row - 2) && row >= 2;
                ")": pixel = (col == 6 - row || col == row + 2) && row >= 2;
                "$": pixel = (row == 1 || row == 5 || col == 1 || col == 3) &&
                             (row != 0 && row != 6);
                "%": pixel = (col == row) || (col == 4 - row);
                "@": pixel = (row == 0 || row == 6 || col == 0 || col == 4 ||
                             (row == 3 && (col != 0 && col != 4)));
                "&": pixel = (row == 3 || col == 0 || col == 4 ||
                             (row <= 3 && col != 2));
                "\"": pixel = (col == 2 && (row == 0 || row == 1));
                ";": pixel = (row == 2 && col == 2) || (row == 4 && col == 2) ||
                             (row == 5 && col == 1);
                "<": pixel = ((col + row == 3) && row > 0 && row < 6) ||
                             (row == 3 && col == 2);
                ">": pixel = ((col - row == -1) && row > 0 && row < 6) ||
                             (row == 3 && col == 2);

                default: pixel = 1'b0;
            endcase
        end
    end

endmodule
