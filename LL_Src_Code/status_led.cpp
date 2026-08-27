#include "status_led.h"
#include <Adafruit_NeoPixel.h>

#define RGB_LED_PIN        38
#define RGB_LED_COUNT      1
#define RGB_LED_BRIGHTNESS 50

static Adafruit_NeoPixel rgb(
    RGB_LED_COUNT,
    RGB_LED_PIN,
    NEO_GRB + NEO_KHZ800
);

void StatusLED_Init()
{
    rgb.begin();
    rgb.setBrightness(RGB_LED_BRIGHTNESS);
    rgb.clear();
    rgb.show();
}

void StatusLED_Red()
{
    rgb.setPixelColor(
        0,
        rgb.Color(255, 0, 0)
    );

    rgb.show();
}

void StatusLED_Green()
{
    rgb.setPixelColor(
        0,
        rgb.Color(0, 255, 0)
    );

    rgb.show();
}

void StatusLED_Blue()
{
    rgb.setPixelColor(
        0,
        rgb.Color(0, 0, 255)
    );

    rgb.show();
}

void StatusLED_Off()
{
    rgb.clear();
    rgb.show();
}