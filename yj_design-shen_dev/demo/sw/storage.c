// storage.c - Data Persistence Layer (SPI Flash)
// Provides read/write interface for external flash storage
//
// Fixes:
//   B7: storage_wait_ready now polls flash busy/done bits in REG_FLASH_RD_DATA
//       (bit 8=busy, bit 9=done), instead of the never-cleared REG_FLASH_CMD.
//       flash command bits are now auto-cleared by hardware on done.
//   B6: storage_write_block now erases sector once, then writes all bytes
//       without per-byte erase, preventing data corruption.
#include "config.h"

// ============================================
// Internal: wait for flash operation to complete
// ============================================
// FIXED B7: polls REG_FLASH_RD_DATA for busy/done status bits.
// Hardware exposes: bit 8=busy, bit 9=done.
// Command bits in REG_FLASH_CMD are auto-cleared by hardware on done.
static int storage_wait_ready(void) {
    uint32_t timeout = 1000000;
    while (timeout--) {
        uint32_t status = REG_FLASH_RD_DATA;
        // Check done bit (bit 9) — operation complete
        if (status & 0x200) {
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
}

// Read data from flash (byte by byte)
int storage_read(uint32_t addr, uint8_t* data, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        // Wait for previous operation
        if (storage_wait_ready() != 0) return -1;

        // Set address
        REG_FLASH_ADDR = addr + i;

        // Trigger read operation (rd_en = bit 1)
        REG_FLASH_CMD = 0x02;

        // Wait for read to complete
        if (storage_wait_ready() != 0) return -2;

        // Read data from register
        data[i] = (uint8_t)(REG_FLASH_RD_DATA & 0xFF);
    }
    return 0;
}

// Write data to flash (byte by byte, no per-byte erase)
// NOTE: caller should erase the sector first via storage_erase_sector()
int storage_write(uint32_t addr, const uint8_t* data, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        if (storage_wait_ready() != 0) return -1;

        REG_FLASH_ADDR    = addr + i;
        REG_FLASH_WR_DATA = data[i];
        // FIXED B6: wr_en (bit 0) now does page program WITHOUT erase
        REG_FLASH_CMD     = 0x01;

        if (storage_wait_ready() != 0) return -2;
    }
    return 0;
}

// Erase a flash sector (4KB)
int storage_erase_sector(uint32_t addr) {
    if (storage_wait_ready() != 0) return -1;

    REG_FLASH_ADDR = addr;
    // FIXED B6: erase_en is bit 2
    REG_FLASH_CMD  = 0x04;

    return storage_wait_ready();
}

// Block write (with sector erase)
// FIXED B6: erases sector once, then writes all bytes without per-byte erase
int storage_write_block(uint32_t addr, const uint8_t* data, uint32_t len) {
    int ret;

    // Align to sector boundary
    uint32_t sector_addr = addr & ~(FLASH_SECTOR_SIZE - 1);

    // Step 1: Erase sector once
    ret = storage_erase_sector(sector_addr);
    if (ret != 0) return ret;

    // Step 2: Write all bytes (each byte is a page program, no erase)
    ret = storage_write(addr, data, len);
    return ret;
}
