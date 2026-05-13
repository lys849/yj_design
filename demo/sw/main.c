// main.c - Main Control Flow
// Fingerprint Payment System - MicroBlaze Application
//
// State machine with the following flows:
//   MAIN MENU -> Account Management -> Create / Delete / Recharge / Query
//   MAIN MENU -> Payment -> Input Amount -> Fingerprint Verify -> Deduct
//
#include "config.h"
#include "fingerprint.h"
#include "account.h"
#include "payment.h"
#include "display.h"
#include "storage.h"

// ============================================
// Global state
// ============================================
static uint8_t  menu_state = MENU_MAIN;
static uint8_t  input_buffer[16];
static uint8_t  input_len = 0;
static uint32_t input_value = 0;

// ============================================
// Keyboard input handler
// ============================================

// Read key from keyboard (blocking)
static uint8_t keyboard_read(void) {
    uint8_t key;
    uint32_t prev = REG_KEYBOARD;

    while (1) {
        uint32_t val = REG_KEYBOARD;
        // Check for key press: bit 4 = valid, bits 3:0 = key code
        if ((val & 0x10) && (val != prev)) {
            key = val & 0x0F;
            // Debounce: wait for release
            while (REG_KEYBOARD & 0x10);
            // Short beep for feedback
            REG_BUZZER = BUZZER_SHORT;
            return key;
        }
        prev = val;
    }
}

// Read a numeric input string (terminated by KEY_A = confirm or KEY_B = cancel)
// Returns: 0 = confirmed, -1 = cancelled
static int input_number(uint32_t* value) {
    input_len = 0;
    input_value = 0;

    while (1) {
        uint8_t key = keyboard_read();

        if (key >= KEY_0 && key <= KEY_9) {
            if (input_len < 10) {
                input_buffer[input_len++] = '0' + key;
                input_value = input_value * 10 + key;
                // Echo to display
                display_put_char(5, 18 + input_len - 1, '0' + key);
            }
        } else if (key == KEY_A) {  // Confirm
            if (value) *value = input_value;
            return 0;
        } else if (key == KEY_B) {  // Cancel
            return -1;
        } else if (key == KEY_F) {  // Clear/Delete
            if (input_len > 0) {
                input_len--;
                input_value /= 10;
                display_put_char(5, 18 + input_len, ' ');
            }
        }
    }
}

// ============================================
// Account management flow
// ============================================

static void flow_account_create(void) {
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"Create Account");
    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"Place finger on sensor...");

    // Enroll fingerprint
    uint16_t fp_id = 1;
    // Find next available FP ID
    for (uint16_t i = 1; i <= MAX_ACCOUNTS; i++) {
        if (!account_exists(i)) {
            fp_id = i;
            break;
        }
    }

    int ret = fp_enroll_fingerprint(fp_id);
    if (ret != 0) {
        display_error((const uint8_t*)"Fingerprint enrollment failed!");
        keyboard_read();
        return;
    }

    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"Fingerprint registered. ID: ");
    display_put_number(4, 34, fp_id);

    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Enter initial deposit (yuan): ");

    uint32_t deposit;
    if (input_number(&deposit) != 0) {
        display_error((const uint8_t*)"Cancelled.");
        fp_delete_template(fp_id);
        keyboard_read();
        return;
    }

    // Create account
    const uint8_t name[] = "User";
    ret = account_create(fp_id, name, deposit * 100);  // convert to cents
    if (ret != 0) {
        display_error((const uint8_t*)"Failed to create account!");
        fp_delete_template(fp_id);
    } else {
        display_success((const uint8_t*)"Account created successfully!");
        REG_BUZZER = BUZZER_OK;
    }
    keyboard_read();
}

static void flow_account_delete(void) {
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"Delete Account");
    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"Place finger on sensor to identify...");

    uint16_t fp_id;
    int ret = fp_identify_fingerprint(&fp_id);
    if (ret != 0) {
        display_error((const uint8_t*)"Fingerprint not recognized!");
        keyboard_read();
        return;
    }

    // Show account info
    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Account: ");
    display_put_string(5, 14, account_get_name(fp_id));
    display_clear_line(6);
    display_put_string(6, 5, (const uint8_t*)"Balance: ");
    display_put_amount(6, 14, account_query_balance(fp_id));
    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"Press A to confirm delete, B to cancel");

    uint8_t key = keyboard_read();
    if (key == KEY_A) {
        ret = account_delete(fp_id);
        fp_delete_template(fp_id);
        if (ret == 0) {
            display_success((const uint8_t*)"Account deleted.");
            REG_BUZZER = BUZZER_OK;
        } else {
            display_error((const uint8_t*)"Delete failed!");
        }
    } else {
        display_status(10, (const uint8_t*)"Delete cancelled.");
    }
    keyboard_read();
}

static void flow_account_recharge(void) {
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"Recharge Balance");
    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"Place finger on sensor...");

    uint16_t fp_id;
    int ret = fp_identify_fingerprint(&fp_id);
    if (ret != 0) {
        display_error((const uint8_t*)"Fingerprint not recognized!");
        keyboard_read();
        return;
    }

    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Account: ");
    display_put_string(5, 14, account_get_name(fp_id));
    display_clear_line(6);
    display_put_string(6, 5, (const uint8_t*)"Current balance: ");
    display_put_amount(6, 22, account_query_balance(fp_id));

    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"Recharge amount (yuan): ");

    uint32_t amount;
    if (input_number(&amount) != 0) {
        display_status(10, (const uint8_t*)"Recharge cancelled.");
        keyboard_read();
        return;
    }

    ret = account_recharge(fp_id, amount * 100);
    if (ret == 0) {
        display_clear_line(9);
        display_put_string(9, 5, (const uint8_t*)"New balance: ");
        display_put_amount(9, 18, account_query_balance(fp_id));
        display_success((const uint8_t*)"Recharge successful!");
        REG_BUZZER = BUZZER_OK;
    } else {
        display_error((const uint8_t*)"Recharge failed!");
    }
    keyboard_read();
}

static void flow_account_query(void) {
    display_clear_line(2);
    display_put_string(2, 5, (const uint8_t*)"Query Balance");
    display_clear_line(4);
    display_put_string(4, 5, (const uint8_t*)"Place finger on sensor...");

    uint16_t fp_id;
    int ret = fp_identify_fingerprint(&fp_id);
    if (ret != 0) {
        display_error((const uint8_t*)"Fingerprint not recognized!");
        keyboard_read();
        return;
    }

    display_clear_line(5);
    display_put_string(5, 5, (const uint8_t*)"Account: ");
    display_put_string(5, 14, account_get_name(fp_id));
    display_clear_line(6);
    display_put_string(6, 5, (const uint8_t*)"Balance: ");
    display_put_amount(6, 14, account_query_balance(fp_id));
    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"Press any key to continue...");

    keyboard_read();
}

// ============================================
// Payment flow
// ============================================

static void flow_payment(void) {
    payment_init();
    display_payment_menu();

    // Step 1: Input amount
    display_put_string(5, 18, (const uint8_t*)"   ");
    uint32_t amount;
    if (input_number(&amount) != 0) {
        display_status(10, (const uint8_t*)"Payment cancelled.");
        keyboard_read();
        return;
    }
    payment_input_digit(amount);
    // Note: our input_number already provides the full amount
    // Reset and use it directly
    payment_clear_amount();
    payment_input_digit(amount);

    // Show amount entered
    display_clear_line(6);
    display_put_string(6, 5, (const uint8_t*)"Amount: ");
    display_put_amount(6, 13, payment_get_amount());

    display_clear_line(8);
    display_put_string(8, 5, (const uint8_t*)"Place finger to confirm payment...");

    // Wait for key A or finger verification
    // In a real system, the fingerprint sensor would auto-trigger
    // For now, wait for confirm key
    uint8_t key = keyboard_read();
    if (key != KEY_A) {
        display_status(10, (const uint8_t*)"Payment cancelled.");
        keyboard_read();
        return;
    }

    // Step 2: Execute payment (fingerprint verification + deduction)
    int ret = payment_execute();
    switch (ret) {
        case 0:
            display_success((const uint8_t*)"Payment successful!");
            break;
        case 1:
            display_clear_line(9);
            display_put_string(9, 5, (const uint8_t*)"Balance: ");
            display_put_amount(9, 14, account_query_balance(payment_get_fp_id()));
            display_error((const uint8_t*)"Insufficient balance!");
            break;
        case 2:
            display_error((const uint8_t*)"Fingerprint not recognized!");
            break;
        default:
            display_error((const uint8_t*)"Payment failed!");
            break;
    }

    keyboard_read();
}

// ============================================
// System initialization
// ============================================

static void system_init(void) {
    // Initialize storage
    storage_init();

    // Initialize account system
    account_init();

    // Initialize payment system
    payment_init();

    // Clear display and show main menu
    display_clear();
    display_main_menu();

    // Startup beep
    REG_BUZZER = BUZZER_SHORT;

    // LED indicates system ready
    REG_LED = 0x01;
}

// ============================================
// Main loop
// ============================================

int main(void) {
    system_init();

    while (1) {
        uint8_t key = keyboard_read();

        if (menu_state == MENU_MAIN) {
            switch (key) {
                case KEY_1:
                    menu_state = MENU_ACCOUNT;
                    display_account_menu();
                    break;
                case KEY_2:
                    flow_payment();
                    display_main_menu();
                    break;
                default:
                    // Ignore other keys in main menu
                    break;
            }
        }
        else if (menu_state == MENU_ACCOUNT) {
            switch (key) {
                case KEY_1:
                    flow_account_create();
                    display_account_menu();
                    break;
                case KEY_2:
                    flow_account_delete();
                    display_account_menu();
                    break;
                case KEY_3:
                    flow_account_recharge();
                    display_account_menu();
                    break;
                case KEY_4:
                    flow_account_query();
                    display_account_menu();
                    break;
                case KEY_B:
                    menu_state = MENU_MAIN;
                    display_main_menu();
                    break;
                default:
                    break;
            }
        }
    }

    return 0;
}
