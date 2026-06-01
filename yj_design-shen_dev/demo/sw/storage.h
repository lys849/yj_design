// storage.h - Storage layer API
#ifndef STORAGE_H
#define STORAGE_H

#include "config.h"

void storage_init(void);
int storage_read(uint32_t addr, uint8_t* data, uint32_t len);
int storage_write(uint32_t addr, const uint8_t* data, uint32_t len);
int storage_erase_sector(uint32_t addr);
int storage_write_block(uint32_t addr, const uint8_t* data, uint32_t len);

#endif /* STORAGE_H */
