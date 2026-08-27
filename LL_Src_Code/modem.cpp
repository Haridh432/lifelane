#include "modem.h"
#include "config.h"

namespace Modem {

HardwareSerial ModemSerial(1);

void begin() {
  ModemSerial.begin(
    MODEM_BAUDRATE,
    SERIAL_8N1,
    MODEM_RX_PIN,
    MODEM_TX_PIN);

  delay(1000);

  LOG_INFO(
    "MODEM",
    "UART initialized");
}

HardwareSerial &serial() {
  return ModemSerial;
}

// --------------------------------------------------------
// Send AT command
// --------------------------------------------------------

String sendCommand(
  const char *command,
  uint32_t timeout) {
  LOG_DEBUG(
    "MODEM",
    "TX: %s",
    command);

  while (ModemSerial.available()) {
    ModemSerial.read();
  }

  ModemSerial.println(command);

  String response;

  uint32_t start = millis();

  // ------------------------------------------------------
  // Exit as soon as a terminal AT response is seen, instead
  // of always burning the full `timeout` window. The modem
  // typically answers in well under 100ms, so returning
  // early here is the single biggest latency win.
  // ------------------------------------------------------
  while (
    millis() - start < timeout) {
    while (ModemSerial.available()) {
      response +=
        (char)ModemSerial.read();

      if (
        response.endsWith("OK\r\n") ||
        response.endsWith("ERROR\r\n") ||
        response.indexOf("DOWNLOAD") >= 0 ||
        response.indexOf("+CME ERROR") >= 0 ||
        response.indexOf("+CMS ERROR") >= 0) {

        uint32_t elapsed = millis() - start;

        if (
          response.indexOf("ERROR") >= 0) {
          LOG_ERROR(
            "MODEM",
            "Command failed (%lums): %s -> %s",
            (unsigned long)elapsed,
            command,
            response.c_str());
        } else {
          LOG_DEBUG(
            "MODEM",
            "RX (%lums): %s",
            (unsigned long)elapsed,
            response.c_str());
        }

        return response;
      }
    }
  }

  // No terminal response before timeout expired.
  LOG_ERROR(
    "MODEM",
    "Timeout (%lums) waiting for response to: %s [partial RX: %s]",
    (unsigned long)timeout,
    command,
    response.c_str());

  return response;
}

// --------------------------------------------------------
// Wait for response
// --------------------------------------------------------

String waitForResponse(
  const char *expected,
  uint32_t timeout) {
  String response;

  uint32_t start = millis();

  while (
    millis() - start < timeout) {
    while (ModemSerial.available()) {
      char c =
        ModemSerial.read();

      response += c;

      if (
        response.indexOf(
          expected)
        >= 0) {
        return response;
      }

      // Bail out immediately on an explicit modem error
      // instead of waiting out the full timeout for a
      // success string that will never arrive.
      if (
        response.endsWith("ERROR\r\n") ||
        response.indexOf("+CME ERROR") >= 0 ||
        response.indexOf("+CMS ERROR") >= 0) {
        LOG_ERROR(
          "MODEM",
          "Modem returned error (%lums) while waiting for '%s': %s",
          (unsigned long)(millis() - start),
          expected,
          response.c_str());

        return response;
      }
    }
  }

  LOG_ERROR(
    "MODEM",
    "Timeout (%lums) waiting for: %s [partial RX: %s]",
    (unsigned long)timeout,
    expected,
    response.c_str());

  return response;
}

// --------------------------------------------------------
// Initialize modem
// --------------------------------------------------------

bool initialize() {
  LOG_INFO(
    "MODEM",
    "Initializing SIM7670G");

  String response =
    sendCommand(
      "AT",
      2000);

  if (
    response.indexOf("OK") < 0) {
    LOG_ERROR(
      "MODEM",
      "Modem not responding");

    return false;
  }

  // ----------------------------------------------------
  // SIM
  // ----------------------------------------------------

  response =sendCommand(
                "AT+CPIN?",
                3000);

  if (
    response.indexOf(
      "READY")
    < 0) {
    LOG_ERROR(
      "MODEM",
      "SIM not ready");

    return false;
  }

  LOG_INFO(
    "MODEM",
    "SIM ready");

  // ----------------------------------------------------
  // Signal
  // ----------------------------------------------------

  sendCommand(
    "AT+CSQ",
    3000);

  // ----------------------------------------------------
  // Network registration
  // ----------------------------------------------------

  sendCommand(
    "AT+CEREG?",
    3000);

  // ----------------------------------------------------
  // Packet service
  // ----------------------------------------------------

  response =
    sendCommand(
      "AT+CGATT?",
      3000);

  if (
    response.indexOf(
      "+CGATT: 1")
    >= 0) {
    LOG_INFO(
      "NETWORK",
      "Packet service attached");
  } else {
    LOG_ERROR(
      "NETWORK",
      "Packet service not attached");
  }

  // ----------------------------------------------------
  // PDP
  // ----------------------------------------------------

  sendCommand(
    "AT+CGDCONT?",
    3000);

  sendCommand(
    "AT+CGACT?",
    3000);

  sendCommand(
    "AT+CGPADDR=1",
    3000);


  LOG_INFO(
    "MODEM",
    "Initialization complete");

  return true;
}

}