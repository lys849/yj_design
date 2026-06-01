// account.c - Account Management System
// Handles account CRUD operations and balance management
#include "config.h"
#include "storage.h"

// In-memory account cache
static account_t accounts[MAX_ACCOUNTS];
static int account_count = 0;
static int initialized = 0;

// ============================================
// Internal helpers
// ============================================

static int find_account_by_fp_id(uint16_t fp_id) {
    for (int i = 0; i < MAX_ACCOUNTS; i++) {
        if (accounts[i].active && accounts[i].fp_id == fp_id) {
            return i;
        }
    }
    return -1;
}

static int find_empty_slot(void) {
    for (int i = 0; i < MAX_ACCOUNTS; i++) {
        if (!accounts[i].active) {
            return i;
        }
    }
    return -1;
}

// ============================================
// Public API
// ============================================

// Load account data from flash into memory
void account_init(void) {
    for (int i = 0; i < MAX_ACCOUNTS; i++) {
        storage_read(FLASH_ACCOUNT_BASE + i * sizeof(account_t),
                     (uint8_t*)&accounts[i], sizeof(account_t));
        if (accounts[i].active) {
            account_count++;
        }
    }
    initialized = 1;
}

// Save all account data back to flash
void account_save_all(void) {
    for (int i = 0; i < MAX_ACCOUNTS; i++) {
        storage_write(FLASH_ACCOUNT_BASE + i * sizeof(account_t),
                      (uint8_t*)&accounts[i], sizeof(account_t));
    }
}

// Save single account to flash
void account_save(int index) {
    if (index >= 0 && index < MAX_ACCOUNTS) {
        storage_write(FLASH_ACCOUNT_BASE + index * sizeof(account_t),
                      (uint8_t*)&accounts[index], sizeof(account_t));
    }
}

// Create a new account
int account_create(uint16_t fp_id, const uint8_t* name, uint32_t initial_balance) {
    if (account_count >= MAX_ACCOUNTS) {
        return -1;  // no space
    }

    int slot = find_empty_slot();
    if (slot < 0) {
        return -2;  // corrupted state
    }

    accounts[slot].fp_id   = fp_id;
    accounts[slot].balance = initial_balance;
    accounts[slot].active  = 1;

    // Copy name
    int i;
    for (i = 0; i < 15 && name[i] != 0; i++) {
        accounts[slot].name[i] = name[i];
    }
    accounts[slot].name[i] = 0;

    account_count++;
    account_save(slot);
    return 0;
}

// Delete an account
int account_delete(uint16_t fp_id) {
    int idx = find_account_by_fp_id(fp_id);
    if (idx < 0) {
        return -1;  // not found
    }

    accounts[idx].active = 0;
    accounts[idx].fp_id  = 0;
    accounts[idx].balance = 0;

    account_count--;
    account_save(idx);
    return 0;
}

// Recharge account balance
int account_recharge(uint16_t fp_id, uint32_t amount) {
    int idx = find_account_by_fp_id(fp_id);
    if (idx < 0) {
        return -1;
    }

    accounts[idx].balance += amount;
    account_save(idx);
    return 0;
}

// Query account balance
uint32_t account_query_balance(uint16_t fp_id) {
    int idx = find_account_by_fp_id(fp_id);
    if (idx < 0) {
        return 0;
    }
    return accounts[idx].balance;
}

// Deduct from account (payment)
int account_deduct(uint16_t fp_id, uint32_t amount) {
    int idx = find_account_by_fp_id(fp_id);
    if (idx < 0) {
        return -1;  // account not found
    }

    if (accounts[idx].balance < amount) {
        return -2;  // insufficient balance
    }

    accounts[idx].balance -= amount;
    account_save(idx);
    return 0;
}

// Check if account exists
int account_exists(uint16_t fp_id) {
    return find_account_by_fp_id(fp_id) >= 0;
}

// Get account name by fingerprint ID
const uint8_t* account_get_name(uint16_t fp_id) {
    int idx = find_account_by_fp_id(fp_id);
    if (idx < 0) {
        return (const uint8_t*)"Unknown";
    }
    return accounts[idx].name;
}
