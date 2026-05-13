// fingerprint.h - Fingerprint Sensor Driver API
#ifndef FINGERPRINT_H
#define FINGERPRINT_H

#include "config.h"

// Low-level commands
int fp_capture_image(void);
int fp_generate_feature(uint8_t buf_id);
int fp_register_model(void);
int fp_store_template(uint16_t page_id);
int fp_load_template(uint16_t page_id);
int fp_delete_template(uint16_t page_id);
int fp_empty_library(void);
int fp_match(uint16_t* score);
int fp_search(uint16_t* page_id, uint16_t* score);
int fp_enroll_check(void);
int fp_read_params(uint16_t* status, uint16_t* capacity, uint16_t* count);

// Composite operations
int fp_enroll_fingerprint(uint16_t page_id);
int fp_verify_fingerprint(uint16_t page_id);
int fp_identify_fingerprint(uint16_t* page_id);

#endif /* FINGERPRINT_H */
