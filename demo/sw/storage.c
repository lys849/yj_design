// storage.c - Data Persistence Layer (SPI Flash)
// Provides read/write interface for external flash storage
#include "config.h"

// ============================================
// Internal: wait for flash operation to complete
// ============================================
static int storage_wait_ready(void) {
    uint32_t timeout = 1000000;
    while (timeout--) {
        uint32_t cmd = REG_FLASH_CMD;
        // Check if flash is idle (wr_en=0, rd_en=0)
        if ((cmd & 0x3) == 0) {
            return 0;
        }
    }
    return -1;  // timeout
}

// ============================================
// Public API
// ============================================

// Initialize flash storage
void storage_init(void) {
    // Flash is self-initializing; nothing needed
    // Could verify flash ID here in production
}

// Read data from flash
// addr: 24-bit flash address (0x000000 - 0xFFFFFF)
// data: output buffer
// len: number of bytes to read
int storage_read(uint32_t addr, uint8_t* data, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        // Wait for previous operation
        if (storage_wait_ready() != 0) return -1;

        // Set address
        REG_FLASH_ADDR = addr + i;

        // Trigger read operation
        REG_FLASH_CMD = 0x02;  // rd_en = 1

        // Wait for read to complete
        if (storage_wait_ready() != 0) return -2;

        // Read data from register
        data[i] = (uint8_t)(REG_FLASH_RD_DATA & 0xFF);
    }
    return 0;
}

// Write data to flash
// Note: For simplicity, this writes byte-by-byte
// In production, use page program (256 bytes at a time)
int storage_write(uint32_t addr, const uint8_t* data, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        if (storage_wait_ready() != 0) return -1;

        REG_FLASH_ADDR    = addr + i;
        REG_FLASH_WR_DATA = data[i];
        REG_FLASH_CMD     = 0x01;  // wr_en = 1

        if (storage_wait_ready() != 0) return -2;
    }
    return 0;
}

// Erase a flash sector (4KB)
int storage_erase_sector(uint32_t addr) {
    if (storage_wait_ready() != 0) return -1;

    REG_FLASH_ADDR = addr;
    REG_FLASH_CMD  = 0x04;  // erase command

    return storage_wait_ready();
}

// Block write (with sector erase)
int storage_write_block(uint32_t addr, const uint8_t* data, uint32_t len) {
    // Align to sector boundary
    uint32_t sector_addr = addr & ~(FLASH_SECTOR_SIZE - 1);

    // Erase sector
    storage_erase_sector(sector_addr);

    // Write data
    return storage_write(addr, data, len);
}
