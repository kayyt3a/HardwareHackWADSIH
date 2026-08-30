// Vocalens firmware — glasses form factor, XIAO ESP32S3 Sense
//
// Trigger: wake word ("hey ..., what does this say?") OR a manual press on
// the temple as a backup — a push button by default, see USE_PUSH_BUTTON in
// pins.h. On trigger: record the spoken question from
// the onboard mic, capture a JPEG frame, POST both to the server, and play
// the returned MP3 answer through a bone-conduction transducer.
//
// Known gotchas carried over from otto_finder's build notes:
//  - PSRAM must be set to OPI PSRAM in board config (see platformio.ini
//    build_flags) or camera init will fail with large frame sizes.
//  - The camera and any other PWM/LEDC-driven peripheral can fight over the
//    same LEDC timer — if you add anything PWM-driven later, give it an
//    explicit LEDC channel away from the camera's.
//  - Verify every pin in pins.h against your specific XIAO ESP32S3 Sense
//    wiring before flashing — camera and mic pins are fixed by the board,
//    everything else is only a suggested layout.
//  - Wake-word detection (wake_word.h) and mic recording (mic_capture.h) are
//    both stubs pending ESP-SR integration — see comments in those files.
//    The manual trigger works standalone without either being finished, so
//    build and test the rest of the pipeline against the button first.

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include "esp_camera.h"
#include "pins.h"
#include "secrets.h"
#include "wake_word.h"
#include "mic_capture.h"
#include "offline_fallback.h"

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

// Manual trigger. USE_PUSH_BUTTON (pins.h) picks which kind of hardware is
// fitted; everything downstream just calls manualTriggered().
//
// Which to pick is a real trade, not a default:
//
//   BUTTON — deterministic, nothing to calibrate. But it needs TWO
//     connections (pin and ground), and a through-hole switch needs a
//     breadboard or soldering to attach to at all.
//
//   TOUCH PAD — ONE wire to any scrap of metal, no ground return. That makes
//     it the better choice when GND pins are already spoken for, and it puts
//     one less thing in the pod. The cost is that it has no fixed threshold:
//     the reading moves with humidity, with how the pad is mounted, and with
//     how close the wearer's head is, so it must be calibrated on the
//     assembled device (the selftest build does this) and rechecked if the
//     build changes.
bool manualTriggered() {
#if USE_PUSH_BUTTON
  // Wired button-to-GND with the internal pull-up enabled, so the pin idles
  // HIGH and reads LOW while pressed. This wiring needs no resistor.
  return digitalRead(PIN_TRIGGER) == LOW;
#else
  // Polarity differs across the ESP32 family: on the original ESP32 the
  // reading FALLS when touched, on the ESP32-S3 it RISES. Run the selftest
  // build once — it prints the baseline, the touched range, and which of
  // these two values to use. Guessing makes the pad fire constantly or never
  // fire, and the wiring looks identical either way.
#if TOUCH_ACTIVE_HIGH
  return touchRead(PIN_TRIGGER) > TOUCH_THRESHOLD;
#else
  return touchRead(PIN_TRIGGER) < TOUCH_THRESHOLD;
#endif
#endif
}

// Implemented in audio_playback.cpp — see that file for ESP8266Audio wiring.
void playMp3Stream(WiFiClient *stream, int contentLength);

// POSTs the JPEG frame + recorded question audio as multipart/form-data to
// /ask and plays back the returned MP3. Multipart is built manually since
// HTTPClient doesn't provide a helper for it.
void captureAskAndSpeak() {
  uint8_t *audioBuf = (uint8_t *)ps_malloc(MIC_BUFFER_BYTES);
  size_t audioLen = audioBuf ? recordQuestion(audioBuf) : 0;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    if (audioBuf) free(audioBuf);
    return;
  }

  if (!wifiConnected) {
    Serial.println("No WiFi — falling back to offline barcode scan");
    handleOfflineFallback(fb);
    esp_camera_fb_return(fb);
    if (audioBuf) free(audioBuf);
    return;
  }

  HTTPClient http;
  String url = String("http://") + SERVER_HOST + ":" + SERVER_PORT + "/ask";
  http.begin(url);

  String boundary = "VocalensBoundary";
  http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary);

  String imagePart = "--" + boundary + "\r\n"
                      "Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n"
                      "Content-Type: image/jpeg\r\n\r\n";
  String midBoundary = "\r\n--" + boundary + "\r\n"
                        "Content-Disposition: form-data; name=\"question_audio\"; filename=\"q.wav\"\r\n"
                        "Content-Type: audio/wav\r\n\r\n";
  String tail = "\r\n--" + boundary + "--\r\n";

  size_t totalLen = imagePart.length() + fb->len +
                     (audioLen > 0 ? midBoundary.length() + audioLen : 0) +
                     tail.length();
  uint8_t *body = (uint8_t *)malloc(totalLen);
  if (!body) {
    Serial.println("Out of memory building request body");
    esp_camera_fb_return(fb);
    if (audioBuf) free(audioBuf);
    http.end();
    return;
  }

  size_t offset = 0;
  memcpy(body + offset, imagePart.c_str(), imagePart.length());
  offset += imagePart.length();
  memcpy(body + offset, fb->buf, fb->len);
  offset += fb->len;
  if (audioLen > 0) {
    memcpy(body + offset, midBoundary.c_str(), midBoundary.length());
    offset += midBoundary.length();
    memcpy(body + offset, audioBuf, audioLen);
    offset += audioLen;
  }
  memcpy(body + offset, tail.c_str(), tail.length());

  int httpCode = http.POST(body, totalLen);
  free(body);
  esp_camera_fb_return(fb);
  if (audioBuf) free(audioBuf);

  if (httpCode == 200) {
    Serial.println("Got response, playing audio");
    WiFiClient *stream = http.getStreamPtr();
    playMp3Stream(stream, http.getSize());
  } else {
    Serial.printf("Server error: %d\n", httpCode);
  }
  http.end();
}

void setup() {
  Serial.begin(115200);

#if USE_PUSH_BUTTON
  // INPUT_PULLUP holds the pin HIGH through an internal resistor, so a plain
  // button shorting it to GND is the whole circuit — no external resistor, and
  // no floating pin reading random noise when nothing is pressed.
  pinMode(PIN_TRIGGER, INPUT_PULLUP);
#endif

  setupWiFi();
  if (!setupCamera()) {
    Serial.println("Halting: camera required");
    while (true) delay(1000);
  }
  setupWakeWord();
  setupMic();
  setupOfflineFallback();
  Serial.println("Glasses ready — say the wake word or press the button");
}

void loop() {
  if (isWakeWordDetected() || manualTriggered()) {
    Serial.println("Triggered — recording question and capturing frame");
    captureAskAndSpeak();
    delay(1000); // debounce: avoid immediately re-triggering on the same tap
  }
  delay(20);
}
