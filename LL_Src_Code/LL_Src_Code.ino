#include <Arduino.h>

#include "config.h"
#include "modem.h"
#include "gnss.h"
#include "firebase.h"
#include "status_led.h"

// ============================================================
// GLOBALS
// ============================================================
LocationData currentLocation;
uint32_t lastLocationUpdate = 0;

// ============================================================
// SETUP
// ============================================================
void setup() {
  #if (CURRENT_LOG_LEVEL > 0)
  Serial.begin(115200);

  delay(2000);

  Serial.println();
  Serial.println("========================================");
  Serial.println(" LifeLane Location Sharing POC");
  Serial.println(" ESP32-S3 + SIM7670G + Firebase");
  Serial.println("========================================");
  #endif
  // Status LED
  StatusLED_Init();
  // --------------------------------------------------------
  // Modem
  // --------------------------------------------------------

  Modem::begin();

  if (!Modem::initialize()) {
    LOG_ERROR(
      "SYSTEM",
      "Modem initialization failed");

    return;
  }

  // --------------------------------------------------------
  // GNSS
  // --------------------------------------------------------

  LOG_INFO("SYSTEM","Starting GNSS Initialization delay");
  delay(5000);
  if (!GNSS::begin()) {
    LOG_ERROR(
      "SYSTEM",
      "GNSS initialization failed");

    return;
  }

  LOG_INFO(
    "SYSTEM",
    "System initialization complete");
}

// ============================================================
// LOOP
// ============================================================

void loop() {
  if (
    lastLocationUpdate == 0 || millis() - lastLocationUpdate >= LOCATION_UPDATE_INTERVAL) 
  {
    
    lastLocationUpdate = millis();

    LOG_INFO(
      "SYSTEM",
      "Starting location cycle");

    // ----------------------------------------------------
    // Get location
    // ----------------------------------------------------

    if (
      GNSS::getLocation(
        currentLocation)) {
      // ------------------------------------------------
      // Upload
      // ------------------------------------------------

      Firebase::uploadLocation(
        currentLocation);
    } else {
      LOG_ERROR(
        "SYSTEM",
        "Failed to acquire location");
    }
  }
  delay(100);
}