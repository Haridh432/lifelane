#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// ============================================================
// LOG LEVEL
// ============================================================

#define LOG_LEVEL_NONE   0
#define LOG_LEVEL_ERROR  1
#define LOG_LEVEL_INFO   2
#define LOG_LEVEL_DEBUG  3

#define CURRENT_LOG_LEVEL LOG_LEVEL_DEBUG

// ============================================================
// LOG MACROS
// ============================================================

#if CURRENT_LOG_LEVEL >= LOG_LEVEL_ERROR

#define LOG_ERROR(tag, format, ...) \
    do { \
        Serial.printf( \
            "[ERROR] [%s] " format "\n", \
            tag, \
            ##__VA_ARGS__ \
        ); \
    } while (0)

#else

#define LOG_ERROR(tag, format, ...) \
    do {} while (0)

#endif


#if CURRENT_LOG_LEVEL >= LOG_LEVEL_INFO

#define LOG_INFO(tag, format, ...) \
    do { \
        Serial.printf( \
            "[INFO ] [%s] " format "\n", \
            tag, \
            ##__VA_ARGS__ \
        ); \
    } while (0)

#else

#define LOG_INFO(tag, format, ...) \
    do {} while (0)

#endif


#if CURRENT_LOG_LEVEL >= LOG_LEVEL_DEBUG

#define LOG_DEBUG(tag, format, ...) \
    do { \
        Serial.printf( \
            "[DEBUG] [%s] " format "\n", \
            tag, \
            ##__VA_ARGS__ \
        ); \
    } while (0)

#else

#define LOG_DEBUG(tag, format, ...) \
    do {} while (0)

#endif


// ============================================================
// MODEM
// ============================================================

#define MODEM_RX_PIN 17
#define MODEM_TX_PIN 18

#define MODEM_BAUDRATE 115200


// ============================================================
// FIREBASE
// ============================================================

#define FIREBASE_HOST \
    "locationsharing-1a5bc-default-rtdb.asia-southeast1.firebasedatabase.app"

#define FIREBASE_DEVICE_ID "tracker001"
#define FIREBASE_MAX_RETRIES       3
#define FIREBASE_RETRY_DELAY_MS    500

// ============================================================
// TIMING
// ============================================================

#define LOCATION_UPDATE_INTERVAL 5000UL

#define MODEM_COMMAND_TIMEOUT 5000UL

#define GNSS_TIMEOUT 5000UL

#define HTTP_TIMEOUT 30000UL

#endif