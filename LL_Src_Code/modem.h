#ifndef MODEM_H
#define MODEM_H

#include <Arduino.h>

namespace Modem
{
    void begin();

    String sendCommand(
        const char *command,
        uint32_t timeout
    );

    String waitForResponse(
        const char *expected,
        uint32_t timeout
    );

    bool initialize();

    HardwareSerial &serial();
}

#endif