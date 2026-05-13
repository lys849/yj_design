// payment.c - Payment Transaction Logic
// Handles payment flow: amount input, fingerprint verify, balance deduct
#include "config.h"
#include "fingerprint.h"
#include "account.h"
#include "display.h"

// ============================================
// Payment state machine
// ============================================
static uint32_t payment_amount = 0;     // amount to pay (in cents)
static uint16_t payment_fp_id = 0;      // verified fingerprint ID
static uint8_t  payment_state = 0;       // 0=idle, 1=input_amount, 2=verify

// Initialize payment
void payment_init(void) {
    payment_amount = 0;
    payment_fp_id  = 0;
    payment_state  = 0;
}

// Input a digit to the payment amount
void payment_input_digit(uint8_t digit) {
    if (digit > 9) return;
    payment_amount = payment_amount * 10 + digit;
}

// Clear payment amount
void payment_clear_amount(void) {
    payment_amount = 0;
}

// Execute payment: verify fingerprint and deduct
// Returns: 0=success, 1=insufficient_balance, 2=no_match, 3=error
int payment_execute(void) {
    if (payment_amount == 0) {
        return 3;  // no amount entered
    }

    // Step 1: Identify fingerprint
    uint16_t fp_id;
    int ret = fp_identify_fingerprint(&fp_id);
    if (ret != 0) {
        REG_BUZZER = BUZZER_FAIL;
        return 2;  // no match
    }

    // Step 2: Check account exists
    if (!account_exists(fp_id)) {
        REG_BUZZER = BUZZER_FAIL;
        return 3;  // no account
    }

    // Step 3: Check balance
    uint32_t balance = account_query_balance(fp_id);
    if (balance < payment_amount) {
        REG_BUZZER = BUZZER_FAIL;
        payment_fp_id = fp_id;
        return 1;  // insufficient balance
    }

    // Step 4: Deduct amount
    ret = account_deduct(fp_id, payment_amount);
    if (ret != 0) {
        REG_BUZZER = BUZZER_FAIL;
        return 3;
    }

    // Success
    payment_fp_id = fp_id;
    REG_BUZZER = BUZZER_OK;

    // Update display with transaction info
    display_clear_line(7);
    display_put_string(7, 5, (const uint8_t*)"Account: ");
    display_put_string(7, 14, account_get_name(fp_id));

    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"Paid: ");
    display_put_amount(8, 11, payment_amount);

    display_clear_line(9);
    display_put_string(9, 5, (const uint8_t*)"Balance: ");
    display_put_amount(9, 14, account_query_balance(fp_id));

    return 0;
}

// Get current payment amount
uint32_t payment_get_amount(void) {
    return payment_amount;
}

// Get last verified fingerprint ID
uint16_t payment_get_fp_id(void) {
    return payment_fp_id;
}
