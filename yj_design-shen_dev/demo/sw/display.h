// display.h - Display API
#ifndef DISPLAY_H
#define DISPLAY_H

#include "config.h"

void display_put_char(int row, int col, uint8_t ch);
void display_put_string(int row, int col, const uint8_t* str);
void display_clear(void);
void display_clear_line(int row);
void display_put_number(int row, int col, uint32_t num);
void display_put_amount(int row, int col, uint32_t cents);

void display_main_menu(void);
void display_account_menu(void);
void display_payment_menu(void);
void display_status(int row, const uint8_t* msg);
void display_success(const uint8_t* msg);
void display_error(const uint8_t* msg);

#endif /* DISPLAY_H */
