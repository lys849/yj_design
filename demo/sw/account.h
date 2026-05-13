// account.h - Account Management API
#ifndef ACCOUNT_H
#define ACCOUNT_H

#include "config.h"

void account_init(void);
void account_save_all(void);
void account_save(int index);

int account_create(uint16_t fp_id, const uint8_t* name, uint32_t initial_balance);
int account_delete(uint16_t fp_id);
int account_recharge(uint16_t fp_id, uint32_t amount);
uint32_t account_query_balance(uint16_t fp_id);
int account_deduct(uint16_t fp_id, uint32_t amount);
int account_exists(uint16_t fp_id);
const uint8_t* account_get_name(uint16_t fp_id);

#endif /* ACCOUNT_H */
