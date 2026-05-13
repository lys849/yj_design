// payment.h - Payment system API
#ifndef PAYMENT_H
#define PAYMENT_H

#include "config.h"

void payment_init(void);
void payment_input_digit(uint8_t digit);
void payment_clear_amount(void);
int payment_execute(void);
uint32_t payment_get_amount(void);
uint16_t payment_get_fp_id(void);

#endif /* PAYMENT_H */
