#include "firebase.h"
#include "config.h"
#include "modem.h"
#include "status_led.h"

namespace Firebase
{

    static bool firebasePUT(
            const String &path,
            const String &json
        )
    {
        LOG_INFO(
            "FIREBASE",
            "PUT: %s",
            path.c_str()
        );

        LOG_DEBUG(
            "FIREBASE",
            "Payload: %s",
            json.c_str()
        );


        // --------------------------------------------------------
        // HTTP INIT
        // --------------------------------------------------------

        Modem::sendCommand(
            "AT+HTTPTERM",
            2000
        );

        String response =
            Modem::sendCommand(
                "AT+HTTPINIT",
                5000
            );


        if (response.indexOf("OK") < 0)
        {
            LOG_ERROR(
                "FIREBASE",
                "HTTPINIT failed, modem said: %s",
                response.c_str()
            );

            return false;
        }

        // --------------------------------------------------------
        // URL
        // --------------------------------------------------------

        String url =
            "AT+HTTPPARA=\"URL\",\"https://" +
            String(FIREBASE_HOST) +
            path +
            ".json\"";

        response =
            Modem::sendCommand(
                url.c_str(),
                5000
            );

        if (response.indexOf("OK") < 0)
        {
            LOG_ERROR(
                "FIREBASE",
                "URL configuration failed, modem said: %s",
                response.c_str()
            );

            Modem::sendCommand(
                "AT+HTTPTERM",
                3000
            );

            return false;
        }


        // --------------------------------------------------------
        // SSL
        // --------------------------------------------------------

        response =
            Modem::sendCommand(
                "AT+HTTPPARA=\"SSLCFG\",0",
                3000
            );


        if (
            response.indexOf("OK") < 0
        )
        {
            LOG_ERROR(
                "FIREBASE",
                "SSL configuration failed, modem said: %s",
                response.c_str()
            );

            Modem::sendCommand(
                "AT+HTTPTERM",
                3000
            );

            return false;
        }


        // --------------------------------------------------------
        // Content type
        // --------------------------------------------------------

        response =
            Modem::sendCommand(
                "AT+HTTPPARA=\"CONTENT\",\"application/json\"",
                3000
            );


        if (
            response.indexOf("OK") < 0
        )
        {
            LOG_ERROR(
                "FIREBASE",
                "Content type configuration failed, modem said: %s",
                response.c_str()
            );

            Modem::sendCommand(
                "AT+HTTPTERM",
                3000
            );

            return false;
        }

        // --------------------------------------------------------
        // Send data size
        // --------------------------------------------------------

        String dataCommand =
            "AT+HTTPDATA=" +
            String(json.length()) +
            ",10000";

        response =
            Modem::sendCommand(
                dataCommand.c_str(),
                3000
            );

        if (
            response.indexOf("DOWNLOAD") < 0
        )
        {
            LOG_ERROR(
                "FIREBASE",
                "HTTPDATA failed, modem said: %s",
                response.c_str()
            );

            Modem::sendCommand(
                "AT+HTTPTERM",
                3000
            );

            return false;
        }


        // --------------------------------------------------------
        // Send JSON
        // --------------------------------------------------------

        Modem::serial().print(
            json
        );


        response =
            Modem::waitForResponse(
                "OK",
                10000
            );


        if (
            response.indexOf("OK") < 0
        )
        {
            LOG_ERROR(
                "FIREBASE",
                "Payload transmission failed, modem said: %s",
                response.c_str()
            );

            Modem::sendCommand(
                "AT+HTTPTERM",
                3000
            );

            return false;
        }


        // --------------------------------------------------------
        // PUT
        //
        // SIM7670G:
        // 0 = GET
        // 1 = POST
        // 2 = HEAD
        // 3 = DELETE
        // 4 = PUT
        // --------------------------------------------------------

        Modem::serial().println(
            "AT+HTTPACTION=4"
        );


        String httpResponse;

        int httpStatus = -1;

        int responseLength = 0;

        uint32_t start =
            millis();


        while (
            millis() - start <
            HTTP_TIMEOUT
        )
        {
            while (
                Modem::serial().available()
            )
            {
                httpResponse +=
                    (char)
                    Modem::serial().read();


                int index =
                    httpResponse.indexOf(
                        "+HTTPACTION:"
                    );


                if (index >= 0)
                {
                    int comma1 =
                        httpResponse.indexOf(
                            ',',
                            index
                        );

                    int comma2 =
                        httpResponse.indexOf(
                            ',',
                            comma1 + 1
                        );


                    if (
                        comma1 >= 0 &&
                        comma2 >= 0
                    )
                    {
                        httpStatus =
                            httpResponse.substring(
                                comma1 + 1,
                                comma2
                            ).toInt();


                        responseLength =
                            httpResponse.substring(
                                comma2 + 1
                            ).toInt();

                        break;
                    }
                }
            }


            if (
                httpStatus >= 0
            )
            {
                break;
            }
        }

        uint32_t actionElapsed =
            millis() - start;

        // ------------------------------------------------
        // Timed out without ever seeing +HTTPACTION at all
        // (as opposed to seeing it with a bad status code,
        // which is handled below). This usually means the
        // TLS handshake or network path stalled.
        // ------------------------------------------------
        if (
            httpStatus < 0
        )
        {
            LOG_ERROR(
                "FIREBASE",
                "HTTPACTION timed out after %lums, no response [partial RX: %s]",
                (unsigned long) actionElapsed,
                httpResponse.c_str()
            );
        }
        else
        {
            LOG_INFO(
                "FIREBASE",
                "HTTP status: %d (took %lums)",
                httpStatus,
                (unsigned long) actionElapsed
            );
        }


        // --------------------------------------------------------
        // Read Firebase response
        // --------------------------------------------------------

        if (
            responseLength > 0
        )
        {
            int readLength =
                min(
                    responseLength,
                    500
                );


            String readCommand =
                "AT+HTTPREAD=0," +
                String(readLength);


            response =
                Modem::sendCommand(
                    readCommand.c_str(),
                    5000
                );


            LOG_DEBUG(
                "FIREBASE",
                "Server response: %s",
                response.c_str()
            );
        }


        // --------------------------------------------------------
        // HTTP TERM
        // --------------------------------------------------------

        Modem::sendCommand(
            "AT+HTTPTERM",
            3000
        );


        // --------------------------------------------------------
        // Result
        // --------------------------------------------------------

        if (
            httpStatus >= 200 &&
            httpStatus < 300
        )
        {
            LOG_INFO(
                "FIREBASE",
                "PUT successful: HTTP %d",
                httpStatus
            );

            return true;
        }


        LOG_ERROR(
            "FIREBASE",
            "PUT failed: HTTP %d, body: %s",
            httpStatus,
            response.c_str()
        );

        return false;
    }

    static bool firebasePUTWithRetry(
        const String &path,
        const String &json
    )
    {
        #if STATUS_LED
        StatusLED_Blue();
        #endif

        uint32_t retryStart =
            millis();

        for (
            int attempt = 1;
            attempt <= FIREBASE_MAX_RETRIES;
            attempt++
        )
        {
            LOG_INFO(
                "FIREBASE",
                "PUT attempt %d/%d",
                attempt,
                FIREBASE_MAX_RETRIES
            );

            uint32_t attemptStart =
                millis();

            bool success =
                firebasePUT(
                    path,
                    json
                );

            uint32_t attemptElapsed =
                millis() - attemptStart;

            if (success)
            {
                LOG_INFO(
                    "FIREBASE",
                    "PUT succeeded on attempt %d (%lums, total %lums)",
                    attempt,
                    (unsigned long) attemptElapsed,
                    (unsigned long) (millis() - retryStart)
                );
#if STATUS_LED
                StatusLED_Green();
#endif
                return true;
            }


            // ------------------------------------------------
            // Failed
            // ------------------------------------------------

            LOG_ERROR(
                "FIREBASE",
                "PUT attempt %d failed after %lums",
                attempt,
                (unsigned long) attemptElapsed
            );


            // Don't delay after final attempt
            if (
                attempt <
                FIREBASE_MAX_RETRIES
            )
            {
                LOG_INFO(
                    "FIREBASE",
                    "Retrying in %lu ms",
                    (unsigned long)
                    FIREBASE_RETRY_DELAY_MS
                );

                delay(
                    FIREBASE_RETRY_DELAY_MS
                );
            }
        }


        LOG_ERROR(
            "FIREBASE",
            "PUT failed after %d attempts (%lums total)",
            FIREBASE_MAX_RETRIES,
            (unsigned long) (millis() - retryStart)
        );
#if STATUS_LED
        StatusLED_Red();
#endif

        return false;
    }

    // --------------------------------------------------------
    // Create JSON
    // --------------------------------------------------------

    static String createJSON(const LocationData &location)
    {
        String json = "{";

        json += "\"latitude\":";
        json += String(
            location.latitude,
            6
        );

        json += ",";

        json += "\"longitude\":";
        json += String(
            location.longitude,
            6
        );
        
        json += ",";

        json += "\"speed\":";
        json += String(
            location.speed,
            2
        );

        json += ",";

        json += "\"date\":\"";
        json += location.date;
        json += "\"";

        json += ",";

        json += "\"time\":\"";
        json += location.time;
        json += "\"";

        // Firebase server timestamp
        json += ",";

        json += "\"lastSeen\":";
        json += "{\".sv\":\"timestamp\"}";

        json += "}";

        return json;
    }


    // --------------------------------------------------------
    // Upload
    // --------------------------------------------------------
    bool uploadLocation(const LocationData &location)
    {
        if (!location.valid)
        {
            LOG_ERROR(
                "FIREBASE",
                "Invalid location"
            );

            StatusLED_Red();

            return false;
        }


        String json =
            createJSON(location);

        // ========================================================
        // Current location
        // ========================================================

        String currentPath =
            "/devices/" +
            String(FIREBASE_DEVICE_ID) +
            "/current";


        bool result =
            firebasePUTWithRetry(
                currentPath,
                json
            );

        if (!result)
        {
            LOG_ERROR(
                "FIREBASE",
                "Current location upload failed"
            );

            StatusLED_Red();

            return false;
        }

        LOG_INFO(
            "FIREBASE",
            "Current location updated"
        );

        StatusLED_Green();

        return true;
    }
}