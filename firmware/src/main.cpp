// PocketLabel firmware — XIAO ESP32S3 Sense
//
// Loop: continuously read distance sensor and drive the vibration motor as
// haptic aim-assist. On button press: capture a JPEG frame, POST it to the
// server, and play the returned MP3 speech through the I2S speaker.
//
// Known gotchas carried over from otto_finder's build notes:
//  - PSRAM must be set to OPI PSRAM in board config (see platformio.ini
//    build_flags) or camera init will fail with large frame sizes.
//  - The camera and any PWM-driven peripheral (vibration motor) can fight
//    over the same LEDC timer. If the vibration motor behaves erratically
//    after camera init, explicitly allocate it a different LEDC channel
//    (see setupVibrationMotor() below).
//  - Verify every pin in pins.h against your specific XIAO ESP32S3 Sense
//    wiring before flashing — camera pins are fixed, everything else is
//    only a suggested layout and may collide with camera pins in practice.

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include "esp_camera.h"
#include "pins.h"
#include "secrets.h"
#include "offline_fallback.h"

// --- Haptic aim-assist tuning ---
static const int TOF_TARGET_MIN_MM = 80;   // ideal read distance range
static const int TOF_TARGET_MAX_MM = 150;
static const int VIBRATION_LEDC_CHANNEL = 4; // deliberately not 0, to avoid
                                              // colliding with camera's LEDC use

bool wifiConnected = false;

void setupWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  wifiConnected = (WiFi.status() == WL_CONNECTED);
  Serial.println(wifiConnected ? "\nWiFi connected" : "\nWiFi FAILED — offline mode");
}

bool setupCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size = FRAMESIZE_VGA; // 640x480 — enough detail for label text,
                                      // small enough to upload fast on WiFi
  config.jpeg_quality = 12;
  config.fb_count = psramFound() ? 2 : 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }
  return true;
}

void setupVibrationMotor() {
  ledcSetup(VIBRATION_LEDC_CHANNEL, 5000, 8);
  ledcAttachPin(PIN_VIBRATION_MOTOR, VIBRATION_LEDC_CHANNEL);
}

void buzz(uint8_t intensity) {
  ledcWrite(VIBRATION_LEDC_CHANNEL, intensity);
}

// Reads distance sensor (implement readDistanceMm() for your specific ToF
// module, e.g. VL53L0X via Adafruit_VL53L0X, or an HC-SR04 ultrasonic).
// Placeholder returns -1 (no reading) so the rest of the pipeline still
// compiles before the sensor is wired up.
int readDistanceMm() {
  // TODO: replace with real sensor read
  return -1;
}

void updateHapticFeedback() {
  int distance = readDistanceMm();
  if (distance < 0) {
    buzz(0);
    return;
  }
  if (distance >= TOF_TARGET_MIN_MM && distance <= TOF_TARGET_MAX_MM) {
    buzz(255); // steady strong buzz = in range
  } else {
    // pulse, softer the further out of range
    int diff = min(abs(distance - TOF_TARGET_MIN_MM), abs(distance - TOF_TARGET_MAX_MM));
    int intensity = max(0, 120 - diff / 4);
    buzz((millis() / 200) % 2 == 0 ? intensity : 0);
  }
}

// POSTs the JPEG frame as multipart/form-data to /read_label and plays back
// the returned MP3. Multipart is built manually since HTTPClient doesn't
// provide a helper for it.
void captureAndSend(int distanceMm) {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    return;
  }

  if (!wifiConnected) {
    Serial.println("No WiFi — falling back to offline barcode scan");
    handleOfflineFallback(fb);
    esp_camera_fb_return(fb);
    return;
  }

  HTTPClient http;
  String url = String("http://") + SERVER_HOST + ":" + SERVER_PORT + "/read_label";
  http.begin(url);

  String boundary = "PocketLabelBoundary";
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);

  String head = "--" + boundary + "\r\n"
                "Content-Disposition: form-data; name=\"distance_mm\"\r\n\r\n" +
                String(distanceMm) + "\r\n"
                "--" + boundary + "\r\n"
                "Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n"
                "Content-Type: image/jpeg\r\n\r\n";
  String tail = "\r\n--" + boundary + "--\r\n";

  size_t totalLen = head.length() + fb->len + tail.length();
  uint8_t *body = (uint8_t *)malloc(totalLen);
  if (!body) {
    Serial.println("Out of memory building request body");
    esp_camera_fb_return(fb);
    http.end();
    return;
  }
  memcpy(body, head.c_str(), head.length());
  memcpy(body + head.length(), fb->buf, fb->len);
  memcpy(body + head.length() + fb->len, tail.c_str(), tail.length());

  int httpCode = http.POST(body, totalLen);
  free(body);
  esp_camera_fb_return(fb);

  if (httpCode == 200) {
    Serial.println("Got response, playing audio");
    WiFiClient *stream = http.getStreamPtr();
    playMp3Stream(stream, http.getSize());
  } else {
    Serial.printf("Server error: %d\n", httpCode);
  }
  http.end();
}

// Implemented in audio_playback.cpp — see that file for ESP8266Audio wiring.
void playMp3Stream(WiFiClient *stream, int contentLength);

void setup() {
  Serial.begin(115200);
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  setupVibrationMotor();
  setupWiFi();
  if (!setupCamera()) {
    Serial.println("Halting: camera required");
    while (true) delay(1000);
  }
  setupOfflineFallback();
  Serial.println("PocketLabel ready");
}

void loop() {
  updateHapticFeedback();

  static bool lastButtonState = HIGH;
  bool buttonState = digitalRead(PIN_BUTTON);
  if (lastButtonState == HIGH && buttonState == LOW) {
    Serial.println("Button pressed — capturing");
    captureAndSend(readDistanceMm());
  }
  lastButtonState = buttonState;

  delay(20);
}
