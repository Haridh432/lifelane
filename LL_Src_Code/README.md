# LifeLane -- ESP32-S3 Location Tracking System

LifeLane is an embedded location-tracking prototype built around the
**Waveshare ESP32-S3 SIM7670G 4G board**. The system acquires GNSS
location data, uses the SIM7670G modem for cellular connectivity, and
uploads the latest location to **Firebase Realtime Database**.

The current implementation is the initial Arduino-based proof of
concept. It is intentionally kept simple and stable as a baseline before
moving to a FreeRTOS-based parallel architecture.

## Project Status

**Current stage:** POC-1 -- Initial Working Prototype

**Baseline tag:** `v0.1.0-poc`

The current POC demonstrates:

-   ESP32-S3 initialization
-   SIM7670G modem communication through UART
-   SIM card and cellular network checks
-   Packet-data connectivity
-   GNSS location acquisition
-   Firebase Realtime Database upload
-   Current-location-only storage
-   Configurable logging
-   WS2812B status LED
-   HTTP success/failure indication
-   Retry handling for failed uploads

The current implementation can experience approximately **20--30 seconds
of end-to-end delay** between GNSS measurement and Firebase reception.
This version is therefore the baseline for future optimization.

## Hardware

### Main Controller

**Waveshare ESP32-S3 SIM7670G 4G board**

The board integrates:

-   ESP32-S3
-   SIM7670G 4G modem
-   GNSS capability
-   SIM card interface
-   USB
-   onboard WS2812B RGB LED

### Important GPIOs

  Function                GPIO
  ------------------ ---------
  SIM7670G UART RX     GPIO 17
  SIM7670G UART TX     GPIO 18
  WS2812B RGB LED      GPIO 38

The onboard RGB LED is a **WS2812B addressable LED**.

## System Architecture

The current POC uses a single-threaded Arduino architecture.

``` text
                    ESP32-S3
                       |
             +---------+---------+
             |                   |
             v                   v
           GNSS              SIM7670G
             |               4G Modem
             |                   |
             +---------+---------+
                       |
                       v
              Parse / Prepare JSON
                       |
                       v
                    HTTP PUT
                       |
                       v
               Firebase RTDB
                       |
                       v
                Android App
```

## Firebase Data Model

The current POC stores only the latest location. Historical location
storage is disabled.

Example:

``` json
{
  "latitude": 11.081192,
  "longitude": 76.989157,
  "altitude": 432.6,
  "speed": 2.30,
  "gnssTimestamp": 1786096705000,
  "lastSeen": 1786096733128
}
```

### Timestamp meaning

-   `gnssTimestamp` --- time reported by GNSS for the location
    measurement.
-   `lastSeen` --- Firebase server timestamp representing when the
    update reached Firebase.

Both use **Unix epoch time in milliseconds**.

The Android application uses `lastSeen` to determine device
freshness/active status. The ESP32 does not maintain an `active` field.

## Location Upload

The target upload interval is approximately:

``` text
5 seconds
```

The upload sequence is:

``` text
GNSS read
   |
Validate location
   |
Create payload
   |
HTTP PUT
   |
Check HTTP response
   |
200 --------> Success
non-200/error -> Retry
```

An accepted AT command is not treated as a successful Firebase upload;
the HTTP response code is checked.

## Status LED

The onboard WS2812B LED is connected to **GPIO 38** and is controlled
through the NeoPixel interface.

Current status concept:

  Condition                     LED
  ----------------------------- -------
  System / GNSS status          Blue
  HTTP 200 / Firebase success   Green
  GNSS failure                  Red
  HTTP / network failure        Red

## Logging

The project uses configurable logging macros such as:

``` cpp
LOG_INFO(...);
LOG_ERROR(...);
```

Logging can be enabled or disabled through project configuration. The
goal is to keep debugging useful during development without scattering
unconditional serial prints throughout the application.

## Project Structure

A typical structure is:

``` text
LL_Src_Code/
|
+-- LL_Src_Code.ino
+-- config.h
+-- logger.h
|
+-- gnss.h
+-- gnss.cpp
|
+-- firebase.h
+-- firebase.cpp
|
+-- status_led.h
+-- status_led.cpp
|
+-- README.md
```

### Main application

`LL_Src_Code.ino`

-   System initialization
-   Module initialization
-   Main application flow

### Configuration

`config.h`

-   UART pins
-   Modem baud rate
-   Firebase configuration
-   Upload interval
-   Debug settings
-   LED configuration

### GNSS module

`gnss.cpp / gnss.h`

-   GNSS communication
-   Location reading
-   NMEA/location parsing
-   GNSS date/time conversion
-   Location validation

### Firebase module

`firebase.cpp / firebase.h`

-   SIM7670G HTTP communication
-   Request construction
-   HTTP response handling
-   Upload retry mechanism

### Status LED

`status_led.cpp / status_led.h`

-   WS2812B initialization
-   RGB status indication
-   LED control

### Logger

`logger.h`

Provides the configurable project logging interface.

## SIM7670G Communication

The ESP32-S3 communicates with the SIM7670G through UART.

``` cpp
#define MODEM_RX 17
#define MODEM_TX 18

HardwareSerial ModemSerial(1);

ModemSerial.begin(
    115200,
    SERIAL_8N1,
    MODEM_RX,
    MODEM_TX
);
```

Typical modem/network checks include:

``` text
AT
AT+CPIN?
AT+CSQ
AT+CEREG?
AT+CGATT?
AT+CGDCONT?
AT+CGACT?
```

HTTP communication is handled through the SIM7670G AT-command interface.


## GNSS Data

The GNSS receiver provides information including:

-   Latitude
-   Longitude
-   Date
-   UTC time
-   Altitude
-   Speed
-   Course

Example raw GNSS data observed during testing:

``` text
1104.8715,N,07659.3494,E,050826,042604.000,432.6,2.30,315.53
```

The firmware converts GNSS coordinates into decimal degrees before
uploading them.

## Error Handling

The current POC handles:

-   GNSS read failure
-   Invalid location data
-   Modem communication failure
-   Network failure
-   HTTP failure
-   Firebase request failure

Conceptually:

``` text
HTTP 200
   |
Success
   |
Green LED

HTTP != 200
   |
Failure
   |
Retry
   |
Red LED
```

## Android Application

The Android application acts as the location receiver.

The ESP32 provides the latest location and timestamps. The Android
application determines whether the device is active based on `lastSeen`.

For example:

``` text
Android current time - Firebase lastSeen
```

If the elapsed time exceeds the configured threshold, the application
can display the device as inactive.

This keeps active/inactive logic out of the embedded firmware and
Firebase.

## Development Environment

``` text
Framework: Arduino
Board: Waveshare ESP32-S3 SIM7670G
IDE: Arduino IDE
Language: C/C++
Database: Firebase Realtime Database
Communication: UART + HTTP
```

The project is being developed incrementally. The Arduino implementation
is the known-good baseline.

## Future RTOS Architecture

After POC-1 is stable, the project will move toward a FreeRTOS-based
architecture.

Planned architecture:

``` text
                    ESP32-S3
                 +------------+
                 |  FreeRTOS   |
                 +------+------+
                        |
             +----------+----------+
             |                     |
             v                     v
        GNSS Task              Firebase Task
          Core 0                  Core 1
             |                     |
             v                     v
      Latest Location         HTTP / SIM7670G
             |                     |
             +----------+----------+
                        |
                        v
                    Firebase
```

Goals:

-   Run GNSS acquisition independently
-   Prevent HTTP operations from blocking GNSS processing
-   Reduce apparent location upload latency
-   Improve responsiveness
-   Improve error recovery
-   Establish a producer/consumer architecture

A shared latest-location buffer protected by FreeRTOS synchronization
primitives is planned.

## Development Roadmap

``` text
v0.1.0-poc
    |
    +-- Initial Arduino implementation
    +-- GNSS
    +-- SIM7670G
    +-- Firebase
    +-- Retry mechanism
    +-- Status LED
          |
          v
v0.2.0-rtos
    |
    +-- FreeRTOS task architecture
          |
          v
v0.3.0-shared-location
    |
    +-- Shared location manager
          |
          v
v0.4.0-parallel-gnss-http
    |
    +-- GNSS and Firebase running independently
          |
          v
v0.5.0-modem-optimization
    |
    +-- SIM7670G / HTTP latency optimization
          |
          v
v1.0.0
    |
    +-- Production candidate
```

Each version should remain independently buildable and testable.

## POC-1 Baseline

``` text
Controller:
ESP32-S3

Modem:
SIM7670G

GNSS:
SIM7670G GNSS

Framework:
Arduino

Upload interval:
~5 seconds

Observed end-to-end delay:
~20–30 seconds

Storage:
Current location only

History:
Disabled

Active status:
Calculated by Android

Status indication:
WS2812B
```

The purpose of POC-1 is to establish a reliable working system before
introducing concurrency and performance optimization.

## Git Workflow

The first working POC is tagged:

``` text
v0.1.0-poc
```

Typical workflow:

``` bash
git status
git add .
git commit -m "POC-1: initial working location tracking system"
git tag -a v0.1.0-poc -m "POC-1 baseline - GNSS location to Firebase"
git push origin main
git push origin v0.1.0-poc
```

Future architecture changes should be developed separately and merged
after verification.

## Testing Checklist

### Modem

-   [ ] `AT` returns `OK`
-   [ ] SIM status is `READY`
-   [ ] Signal strength is acceptable
-   [ ] Network registration succeeds
-   [ ] Packet service is attached
-   [ ] PDP context is active
-   [ ] Internet connectivity works

### GNSS

-   [ ] GNSS data is received
-   [ ] Latitude is valid
-   [ ] Longitude is valid
-   [ ] Timestamp is valid
-   [ ] Coordinates are converted correctly

### Firebase

-   [ ] HTTP request is generated
-   [ ] Firebase accepts the request
-   [ ] HTTP 200 is detected
-   [ ] Failed requests are retried
-   [ ] Only current location is stored
-   [ ] `lastSeen` is updated

### Status LED

-   [ ] GPIO38 is configured
-   [ ] WS2812B initializes
-   [ ] Red works
-   [ ] Green works
-   [ ] Blue works
-   [ ] Error states are indicated correctly

### Android

-   [ ] Current location is received
-   [ ] Map position updates
-   [ ] `lastSeen` is read
-   [ ] Device freshness is calculated
-   [ ] Inactive state is displayed after timeout

## License

This project is currently an internal development/POC project.

Add an appropriate license before public distribution.
