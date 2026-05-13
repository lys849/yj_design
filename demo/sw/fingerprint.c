// fingerprint.c - Fingerprint Sensor Driver
// Implements high-level API for AS608 optical fingerprint sensor
#include "config.h"

// ============================================
// Low-level: send command to fingerprint sensor
// ============================================
static int fp_send_command(uint8_t cmd, uint16_t param) {
    // Build 32-bit command word: {start_bit, opcode[7:0], param[15:0]}
    uint32_t cmd_word = (1u << 31) | ((uint32_t)cmd << 16) | (uint32_t)param;

    REG_FP_CMD = cmd_word;

    // Wait for command to complete (poll status)
    uint32_t timeout = 1000000;
    while (timeout--) {
        uint32_t resp = REG_FP_RESP;
        if ((resp >> 24) != 0) {  // status != idle
            return 0;  // success
        }
    }
    return -1;  // timeout
}

// ============================================
// High-level API
// ============================================

// Capture fingerprint image from sensor
int fp_capture_image(void) {
    return fp_send_command(FP_CMD_GET_IMAGE, 0);
}

// Generate feature character file from image buffer
int fp_generate_feature(uint8_t buf_id) {
    return fp_send_command(FP_CMD_GEN_CHAR, buf_id);
}

// Combine two feature files into a template (register model)
int fp_register_model(void) {
    return fp_send_command(FP_CMD_REG_MODEL, 0);
}

// Store template to flash library
int fp_store_template(uint16_t page_id) {
    return fp_send_command(FP_CMD_STORE, page_id);
}

// Load template from flash library
int fp_load_template(uint16_t page_id) {
    return fp_send_command(FP_CMD_LOAD_CHAR, page_id);
}

// Delete template from flash library
int fp_delete_template(uint16_t page_id) {
    return fp_send_command(FP_CMD_DELETE, page_id);
}

// Empty entire fingerprint library
int fp_empty_library(void) {
    return fp_send_command(FP_CMD_EMPTY, 0);
}

// 1:1 match - compare current finger with loaded template
int fp_match(uint16_t* score) {
    int ret = fp_send_command(FP_CMD_MATCH, 0);
    if (ret == 0) {
        // Read response: lower 16 bits contain match score
        uint32_t resp = REG_FP_RESP;
        if (score) *score = resp & 0xFFFF;
    }
    return ret;
}

// 1:N search - search finger in entire library
int fp_search(uint16_t* page_id, uint16_t* score) {
    // Search from page 1 to MAX_ACCOUNTS
    int ret = fp_send_command(FP_CMD_SEARCH, (1 << 8) | MAX_ACCOUNTS);
    if (ret == 0) {
        uint32_t resp = REG_FP_RESP;
        if (page_id) *page_id = (resp >> 8) & 0xFF;
        if (score) *score = resp & 0xFF;
    }
    return ret;
}

// Enroll fingerprint - check if already exists
int fp_enroll_check(void) {
    return fp_send_command(FP_CMD_ENROLL, 0);
}

// Read system parameters
int fp_read_params(uint16_t* status, uint16_t* capacity, uint16_t* count) {
    int ret = fp_send_command(FP_CMD_READ_PARAM, 0);
    if (ret == 0) {
        uint32_t resp = REG_FP_RESP;
        if (status)   *status   = (resp >> 24) & 0xFF;
        if (capacity) *capacity = (resp >> 16) & 0xFF;
        if (count)    *count    = resp & 0xFF;
    }
    return ret;
}

// ============================================
// Composite operations
// ============================================

// Full fingerprint enrollment flow
// Returns: 0=success, <0=error code
int fp_enroll_fingerprint(uint16_t page_id) {
    int ret;

    // Step 1: Capture first image
    ret = fp_capture_image();
    if (ret != 0) return -1;

    // Step 2: Generate feature file 1
    ret = fp_generate_feature(1);
    if (ret != 0) return -2;

    // Step 3: Capture second image
    ret = fp_capture_image();
    if (ret != 0) return -3;

    // Step 4: Generate feature file 2
    ret = fp_generate_feature(2);
    if (ret != 0) return -4;

    // Step 5: Register model (combine both features)
    ret = fp_register_model();
    if (ret != 0) return -5;

    // Step 6: Store template
    ret = fp_store_template(page_id);
    if (ret != 0) return -6;

    return 0;
}

// Verify fingerprint against stored template
// Returns: 0=match, -1=no match, -2=error
int fp_verify_fingerprint(uint16_t page_id) {
    int ret;

    // Step 1: Load template
    ret = fp_load_template(page_id);
    if (ret != 0) return -2;

    // Step 2: Capture image
    ret = fp_capture_image();
    if (ret != 0) return -2;

    // Step 3: Generate feature
    ret = fp_generate_feature(1);
    if (ret != 0) return -2;

    // Step 4: Match
    uint16_t score;
    ret = fp_match(&score);
    if (ret != 0) return -2;

    // Score threshold: > 80 is considered a match
    return (score > 80) ? 0 : -1;
}

// Identify fingerprint (1:N search)
// Returns: page_id if found, -1 if not found
int fp_identify_fingerprint(uint16_t* page_id) {
    // Capture and process
    int ret = fp_capture_image();
    if (ret != 0) return -2;

    ret = fp_generate_feature(1);
    if (ret != 0) return -2;

    uint16_t pid, score;
    ret = fp_search(&pid, &score);
    if (ret != 0) return -2;

    if (score > 80) {
        if (page_id) *page_id = pid;
        return 0;
    }
    return -1;
}
