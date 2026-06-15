// config.h - System Configuration Constants
// Fingerprint Payment System - MicroBlaze Software

#ifndef CONFIG_H
#define CONFIG_H

// ============================================
// System clock and timing
// ============================================
#define CLK_FREQ_HZ         100000000
#define BAUD_RATE            57600

// ============================================
// Memory map (AXI peripheral addresses)
// ============================================
#define REG_BASE             0x40000000

// Fingerprint sensor registers
#define REG_FP_CMD           (*(volatile uint32_t*)(REG_BASE + 0x0000))
#define REG_FP_RESP          (*(volatile uint32_t*)(REG_BASE + 0x0004))

// Keyboard registers
#define REG_KEYBOARD         (*(volatile uint32_t*)(REG_BASE + 0x0008))

// Buzzer control
#define REG_BUZZER           (*(volatile uint32_t*)(REG_BASE + 0x000C))

// SPI Flash
#define REG_FLASH_CMD        (*(volatile uint32_t*)(REG_BASE + 0x0010))
#define REG_FLASH_ADDR       (*(volatile uint32_t*)(REG_BASE + 0x0014))
#define REG_FLASH_WR_DATA    (*(volatile uint32_t*)(REG_BASE + 0x0018))
#define REG_FLASH_RD_DATA    (*(volatile uint32_t*)(REG_BASE + 0x001C))

// VGA character buffer
#define REG_VGA_CHAR         (*(volatile uint32_t*)(REG_BASE + 0x0020))

// LED
#define REG_LED              (*(volatile uint32_t*)(REG_BASE + 0x0024))

// ============================================
// Fingerprint sensor commands (AS608 protocol)
// ============================================
#define FP_CMD_GET_IMAGE     0x01
#define FP_CMD_GEN_CHAR      0x02
#define FP_CMD_MATCH         0x03
#define FP_CMD_SEARCH        0x04
#define FP_CMD_REG_MODEL     0x05
#define FP_CMD_STORE         0x06
#define FP_CMD_LOAD_CHAR     0x07
#define FP_CMD_UP_CHAR       0x08
#define FP_CMD_DOWN_CHAR     0x09
#define FP_CMD_UP_IMAGE      0x0A
#define FP_CMD_DOWN_IMAGE    0x0B
#define FP_CMD_DELETE        0x0C
#define FP_CMD_EMPTY         0x0D
#define FP_CMD_READ_PARAM    0x0F
#define FP_CMD_ENROLL        0x10
#define FP_CMD_READ_INDEX    0x1F

// ============================================
// Fingerprint sensor response codes (AS60x protocol)
// ============================================
#define FP_OK                0x00
#define FP_ERR_RECV          0x01
#define FP_ERR_NO_FINGER     0x02
#define FP_ERR_CAPTURE       0x03
#define FP_ERR_DRY           0x04
#define FP_ERR_WET           0x05
#define FP_ERR_MESSY         0x06
#define FP_ERR_FEW_FEATURE   0x07
#define FP_ERR_NO_MATCH      0x08
#define FP_ERR_NOT_FOUND     0x09
#define FP_ERR_MERGE_FAIL    0x0A
#define FP_ERR_ADDR_RANGE    0x0B
#define FP_ERR_TEMPLATE_RD   0x0C
#define FP_ERR_UPLOAD        0x0D
#define FP_ERR_NO_FOLLOWUP   0x0E
#define FP_ERR_IMG_UPLOAD    0x0F
#define FP_ERR_DELETE        0x10
#define FP_ERR_CLEAR         0x11
#define FP_ERR_PWD           0x13
#define FP_ERR_FLASH         0x18
#define FP_ERR_ENROLL        0x1E
#define FP_ERR_DB_FULL       0x1F

// ============================================
// System constants
// ============================================
#define MAX_ACCOUNTS          32        // Maximum registered accounts
#define MAX_STR_LEN           32        // Maximum string length
#define FLASH_SECTOR_SIZE     4096      // 4KB per sector

// Flash address layout
#define FLASH_FP_TEMPLATE_BASE  0x00000000  // Fingerprint templates: 32 * 512 = 16KB
#define FLASH_ACCOUNT_BASE      0x00010000  // Account data: 32 * 64 = 2KB
#define FLASH_FP_ID_BASE        0x00020000  // Fingerprint ID mapping

// VGA display dimension
#define VGA_COLS              80
#define VGA_ROWS              30

// Buzzer patterns
#define BUZZER_SHORT          0x01
#define BUZZER_OK             0x02
#define BUZZER_FAIL           0x04

// ============================================
// Menu states
// ============================================
#define MENU_MAIN             0
#define MENU_ACCOUNT          1
#define MENU_PAYMENT          2
#define MENU_ACCOUNT_CREATE   3
#define MENU_ACCOUNT_DELETE   4
#define MENU_ACCOUNT_RECHARGE 5
#define MENU_ACCOUNT_QUERY    6
#define MENU_PAYMENT_AMOUNT   7
#define MENU_PAYMENT_VERIFY   8

// ============================================
// Key codes (4x4 matrix)
// ============================================
#define KEY_0                 0
#define KEY_1                 1
#define KEY_2                 2
#define KEY_3                 3
#define KEY_4                 4
#define KEY_5                 5
#define KEY_6                 6
#define KEY_7                 7
#define KEY_8                 8
#define KEY_9                 9
#define KEY_A                 10    // Function: confirm
#define KEY_B                 11    // Function: cancel/back
#define KEY_C                 12    // Function: up
#define KEY_D                 13    // Function: down
#define KEY_E                 14    // Function: menu
#define KEY_F                 15    // Function: delete/clear

// ============================================
// Type definitions
// ============================================
typedef unsigned char  uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int   uint32_t;

typedef struct {
    uint16_t fp_id;             // fingerprint template ID (1-32)
    uint8_t  name[16];          // account name
    uint32_t balance;           // current balance (in cents)
    uint8_t  active;            // 1=active, 0=deleted
    uint8_t  reserved[9];       // padding to 64 bytes
} account_t;

#endif /* CONFIG_H */
