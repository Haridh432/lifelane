#include "gnss.h"
#include "config.h"
#include "modem.h"
#include "status_led.h"

namespace GNSS {

// --------------------------------------------------------
// NMEA coordinate conversion
// --------------------------------------------------------
static double nmeaToDecimal(const String &value,char direction) 
{
    double raw =
        value.toDouble();

    int degrees =
        (int)(raw / 100.0);

    double minutes =
        raw - (degrees * 100.0);

    double decimal =
        degrees + minutes / 60.0;

    if (
        direction == 'S' || direction == 'W') {
        decimal = -decimal;
    }

    return decimal;
}

    // Unix Timestamp Function
static uint64_t createUnixTimestamp(
    const String &date,
    const String &time) 
{
    if (date.length() < 10 || time.length() < 8) {
        return 0;
    }

    // --------------------------------------------------------
    // Extract date
    // YYYY-MM-DD
    // --------------------------------------------------------

    int year =
        date.substring(0, 4).toInt();

    int month =
        date.substring(5, 7).toInt();

    int day =
        date.substring(8, 10).toInt();


    // --------------------------------------------------------
    // Extract time
    // HH:MM:SS
    // --------------------------------------------------------

    int hour =
        time.substring(0, 2).toInt();

    int minute =
        time.substring(3, 5).toInt();

    int second =
        time.substring(6, 8).toInt();


    // --------------------------------------------------------
    // Validate
    // --------------------------------------------------------

    if (year < 1970 || month < 1 || month > 12 || day < 1 || day > 31 || 
        hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 59) {
        return 0;
    }

    // --------------------------------------------------------
    // Calculate days from 1970-01-01
    // --------------------------------------------------------

    uint64_t days = 0;


    // Complete years
    for (int y = 1970; y < year; y++) {
        bool leap =
        ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0);

        days += leap ? 366 : 365;
    }


    // Days in each month
    const int daysInMonth[] = {
        31, 28, 31, 30,
        31, 30, 31, 31,
        30, 31, 30, 31
    };


    // Complete months
    for (int m = 1; m < month; m++) {
        days += daysInMonth[m - 1];


        // February in leap year
        if (
        m == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0))) {
        days++;
        }
    }


    // Complete days
    days += day - 1;


    // --------------------------------------------------------
    // Convert to seconds
    // --------------------------------------------------------

    uint64_t timestamp =
        days * 86400ULL;


    timestamp +=
        hour * 3600ULL;

    timestamp +=
        minute * 60ULL;

    timestamp +=
        second;


    // --------------------------------------------------------
    // Milliseconds
    // GNSS format:
    // HHMMSS.sss
    // --------------------------------------------------------

    int dotIndex =
        time.indexOf('.');


    if (dotIndex >= 0) {
        String millisecondsString =
        time.substring(dotIndex + 1);

        while (
        millisecondsString.length() < 3) {
        millisecondsString += "0";
        }

        int milliseconds =
        millisecondsString
            .substring(0, 3)
            .toInt();

        timestamp =
        timestamp * 1000ULL + milliseconds;
    } else {
        timestamp =
        timestamp * 1000ULL;
    }


    return timestamp;
}


// --------------------------------------------------------
// GNSS begin
// --------------------------------------------------------

bool begin() {
  LOG_INFO(
    "GNSS",
    "Initializing GNSS");

  String response =
    Modem::sendCommand(
      "AT+CGNSSPWR=1",
      5000);

  if (
    response.indexOf("OK") < 0) {
    LOG_ERROR(
      "GNSS",
      "Failed to enable GNSS");

    return false;
  }

  LOG_INFO(
    "GNSS",
    "GNSS enabled");

  return true;
}


// --------------------------------------------------------
// Get location
// --------------------------------------------------------

bool getLocation(LocationData &location) 
{
      location.valid = false;

      LOG_INFO(
        "GNSS",
        "Reading location");

      HardwareSerial &serial =
        Modem::serial();


      while (serial.available()) {
        serial.read();
      }

      serial.println("AT+CGPSINFO");

      String response;

      uint32_t start =
        millis();

      while (millis() - start < GNSS_TIMEOUT) {
        while (serial.available()) {
          response += (char)serial.read();
        }
      }


      LOG_DEBUG(
        "GNSS",
        "Raw response: %s",
        response.c_str());


      int index =
        response.indexOf(
          "+CGPSINFO:");


      if (index < 0) {
        LOG_ERROR(
          "GNSS",
          "GNSS response not found");

        return false;
      }


      String data =
        response.substring(
          index + 10);

      data.trim();


      // ----------------------------------------------------
      // Parse fields
      // ----------------------------------------------------

      String fields[9];

      int fieldIndex = 0;
      int startIndex = 0;


      for (
        int i = 0;
        i <= data.length();
        i++) 
      {
        if (
          i == data.length() || data.charAt(i) == ',') {
          if (
            fieldIndex < 9) {
            fields[fieldIndex] =
              data.substring(
                startIndex,
                i);
          }

          fieldIndex++;

          startIndex = i + 1;
        }
      }


      if (
        fieldIndex < 9) {
        LOG_ERROR(
          "GNSS",
          "Invalid GNSS data");

        return false;
      }


      // ----------------------------------------------------
      // Check valid coordinates
      // ----------------------------------------------------

      if (
        fields[0].length() == 0 || fields[1].length() == 0 || fields[2].length() == 0 || fields[3].length() == 0) {
        LOG_ERROR(
          "GNSS",
          "Location not available");

        return false;
      }


      // ----------------------------------------------------
      // Convert
      // ----------------------------------------------------

      // Latitude
      location.latitude =
        nmeaToDecimal(
          fields[0],
          fields[1].charAt(0));

      // Longitude
      location.longitude =
        nmeaToDecimal(
          fields[2],
          fields[3].charAt(0));

      // Date
      if (fields[4].length() >= 6) {
        snprintf(location.date, sizeof(location.date),
                "20%s-%s-%s",
                fields[4].substring(4, 6).c_str(),
                fields[4].substring(2, 4).c_str(),
                fields[4].substring(0, 2).c_str());
      } else {
        strcpy(location.date, "0000-00-00");
      }

      // Time
      if (fields[5].length() >= 6) {
        String rawTime = fields[5];
        snprintf(location.time, sizeof(location.time),
                "%s:%s:%s",
                rawTime.substring(0, 2).c_str(),
                rawTime.substring(2, 4).c_str(),
                rawTime.substring(4).c_str());
      } else {
        strcpy(location.time, "00:00:00");
      }

      // Speed
      location.speed =
        fields[7].toDouble();

      location.valid = true;

      // ----------------------------------------------------
      // Logs
      // ----------------------------------------------------

      LOG_INFO(
        "GNSS",
        "Latitude: %.6f",
        location.latitude);

      LOG_INFO(
        "GNSS",
        "Longitude: %.6f",
        location.longitude);

      LOG_DEBUG(
        "GNSS",
        "Speed: %.2f",
        location.speed);

      LOG_DEBUG(
        "GNSS",
        "Date: %s",
        location.date);

      LOG_DEBUG(
        "GNSS",
        "Time: %s",
        location.time);

      return true;
    }
}