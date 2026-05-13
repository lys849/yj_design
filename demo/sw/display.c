// display.c - VGA Display Management
// Writes text to the character buffer for VGA display
#include "config.h"

// ============================================
// Internal: Convert row,column to character address
// ============================================
static uint32_t display_char_addr(int row, int col) {
    if (row < 0) row = 0;
    if (row >= VGA_ROWS) row = VGA_ROWS - 1;
    if (col < 0) col = 0;
    if (col >= VGA_COLS) col = VGA_COLS - 1;
    return row * VGA_COLS + col;
}

// ============================================
// Public API
// ============================================

// Write single character to position
void display_put_char(int row, int col, uint8_t ch) {
    uint32_t addr = display_char_addr(row, col);
    REG_VGA_CHAR = (1u << 31) | (addr << 12) | ch;

    // Small delay for write to take effect
    for (volatile int i = 0; i < 100; i++);
}

// Write string at specified position
void display_put_string(int row, int col, const uint8_t* str) {
    while (*str) {
        display_put_char(row, col, *str);
        col++;
        str++;
    }
}

// Clear entire display
void display_clear(void) {
    for (int r = 0; r < VGA_ROWS; r++) {
        for (int c = 0; c < VGA_COLS; c++) {
            REG_VGA_CHAR = (1u << 31) | (((r * VGA_COLS + c) & 0x7FF) << 12) | ' ';
            for (volatile int i = 0; i < 10; i++);
        }
    }
}

// Clear a specific line
void display_clear_line(int row) {
    display_put_string(row, 0, (const uint8_t*)"                                                                                ");
}

// Write a number (integer) at position
void display_put_number(int row, int col, uint32_t num) {
    char buf[16];
    int i = 0;

    if (num == 0) {
        display_put_char(row, col, '0');
        return;
    }

    while (num > 0 && i < 15) {
        buf[i++] = '0' + (num % 10);
        num /= 10;
    }
    buf[i] = 0;

    // Reverse and display
    while (i > 0) {
        display_put_char(row, col, buf[--i]);
        col++;
    }
}

// Write amount in yuan (in cents internally)
void display_put_amount(int row, int col, uint32_t cents) {
    uint32_t yuan = cents / 100;
    uint32_t fen  = cents % 100;

    display_put_string(row, col, (const uint8_t*)"\x24");  // ¥ sign
    col++;
    display_put_number(row, col, yuan);
    col += (yuan == 0) ? 1 : 0;
    while (yuan >= 10) { col++; yuan /= 10; }

    display_put_char(row, col, '.');
    col++;

    uint8_t d1 = '0' + (fen / 10);
    uint8_t d2 = '0' + (fen % 10);
    display_put_char(row, col, d1);
    display_put_char(row, col + 1, d2);
}

// ============================================
// Menu display functions
// ============================================

// Show main menu
void display_main_menu(void) {
    display_clear_line(0);
    display_put_string(0, 30, (const uint8_t*)"====== FINGERPRINT PAYMENT SYSTEM ======");
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"1. Account Management");
    display_clear_line(3);
    display_put_string(3, 5, (const uint8_t*)"2. Payment");
    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Press key to select...");
    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"System Status: Ready");
}

// Show account management menu
void display_account_menu(void) {
    display_clear_line(0);
    display_put_string(0, 30, (const uint8_t*)"===== ACCOUNT MANAGEMENT =====");
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"1. Create Account");
    display_clear_line(3);
    display_put_string(3, 5, (const uint8_t*)"2. Delete Account");
    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"3. Recharge Balance");
    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"4. Query Balance");
    display_clear_line(7);
    display_put_string(7, 5, (const uint8_t*)"Press B to return to main menu");
}

// Show payment menu
void display_payment_menu(void) {
    display_clear_line(0);
    display_put_string(0, 30, (const uint8_t*)"========= PAYMENT =========");
    display_clear_line(3);
    display_put_string(3, 5, (const uint8_t*)"Place finger on sensor...");
    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Enter amount: ");
}

// Show status message
void display_status(int row, const uint8_t* msg) {
    display_clear_line(row);
    display_put_string(row, 5, msg);
}

// Show success message
void display_success(const uint8_t* msg) {
    display_status(10, (const uint8_t*)"[OK] ");
    display_put_string(10, 10, msg);
    display_status(12, (const uint8_t*)"Press any key to continue...");
}

// Show error message
void display_error(const uint8_t* msg) {
    display_status(10, (const uint8_t*)"[ERROR] ");
    display_put_string(10, 13, msg);
    display_status(12, (const uint8_t*)"Press any key to continue...");
}
