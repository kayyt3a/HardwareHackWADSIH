#pragma once

// XIAO ESP32S3 Sense camera pins (fixed, do not change — matches onboard camera)
#define PWDN_GPIO_NUM -1
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 10
#define SIOD_GPIO_NUM 40
#define SIOC_GPIO_NUM 39
#define Y9_GPIO_NUM 48
#define Y8_GPIO_NUM 11
#define Y7_GPIO_NUM 12
#define Y6_GPIO_NUM 14
#define Y5_GPIO_NUM 16
#define Y4_GPIO_NUM 18
#define Y3_GPIO_NUM 17
#define Y2_GPIO_NUM 15
#define VSYNC_GPIO_NUM 38
#define HREF_GPIO_NUM 47
#define PCLK_GPIO_NUM 13

// User-wired peripherals — adjust to match your build. XIAO ESP32S3 Sense
// exposes a limited set of GPIO once the camera/mic are in use; verify each
// against the board pinout diagram before wiring.
//
// Glasses form factor: the onboard PDM mic (fixed pins, part of the Sense
// expansion board) is used both for wake-word listening and for recording
// the spoken question. Output audio goes out a SEPARATE I2S peripheral to a
// bone-conduction transducer via a small amp (e.g. MAX98357A) — the ESP32-S3
// has two I2S peripherals, so mic-in and speaker-out don't collide, but
// double check this against whatever amp/transducer you actually source.
// Manual trigger hardware. Set USE_PUSH_BUTTON to 1 for a push button (the
// recommended option — deterministic, nothing to calibrate), or 0 for a
// capacitive touch pad.
//
// BUTTON WIRING: one leg to PIN_TRIGGER, the other leg to GND. Nothing else.
// The internal pull-up is enabled in setup(), so the pin idles HIGH and reads
// LOW while pressed — no external resistor needed.
//
// GOTCHA: GPIO 3 is a strapping pin on the ESP32-S3 (JTAG source select). It
// is fine in normal use, but do not hold the button down while the board is
// powering up. If that ever becomes awkward, move PIN_TRIGGER to GPIO 2 (pad
// D1) instead; nothing else in the firmware depends on this number.
#define USE_PUSH_BUTTON 0   // 0 = capacitive pad (built): one wire, no ground return
#define PIN_TRIGGER 3         // pad D2 on the silkscreen. Button, or touch pad.

// Touch-pad settings — only used when USE_PUSH_BUTTON is 0. Both values come
// from running the selftest build, which measures your actual pad and prints
// the two numbers to set here. Do not guess them.
//
// A touch pad needs ONE wire and no ground connection, which is why it is the
// better choice when GND pins are already spoken for.
#define TOUCH_ACTIVE_HIGH 1   // ESP32-S3 readings rise on touch; classic ESP32 falls
#define TOUCH_THRESHOLD 40000 // placeholder — replace with the selftest's number
#define PIN_I2S_BCLK 7        // I2S out to amp -> bone-conduction transducer
#define PIN_I2S_LRC 8
#define PIN_I2S_DIN 9
