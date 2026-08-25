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
#define PIN_BUTTON 1        // momentary push button, INPUT_PULLUP, active LOW
#define PIN_VIBRATION_MOTOR 2 // vibration motor via transistor, PWM-capable pin
#define PIN_TOF_SDA 5        // I2C to ToF/distance sensor (e.g. VL53L0X)
#define PIN_TOF_SCL 6
#define PIN_I2S_BCLK 7       // I2S to MAX98357A amp for speech playback
#define PIN_I2S_LRC 8
#define PIN_I2S_DIN 9
