#ifndef GNSS_H
#define GNSS_H

#include <Arduino.h>

struct LocationData
{
    double latitude;
    double longitude;
    double speed;

    char date[11];      // YYYY-MM-DD
    char time[13];      // HH:MM:SS in UTC

    bool valid;
};

namespace GNSS
{
    bool begin();

    bool getLocation(
        LocationData &location
    );
}

#endif