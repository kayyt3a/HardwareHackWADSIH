// Vocalens hardware self-test
//
// Flash this INSTEAD of main.cpp to find out which part of the build works
// and which doesn't. It exercises each subsystem on its own and prints a
// pass/fail table, so a failure points at one component rather than leaving
// you guessing between six.
//
//   pio run -e selftest -t upload && pio device monitor -e selftest
//
// Order is deliberate — each test only depends on the ones above it, so the
// FIRST failure in the list is the one to fix. Everything below a failure is
// unreliable, not necessarily broken.
//
// Nothing here talks to the Vocalens server or spends an API call.

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <AudioOutputI2S.h>
#include "esp_camera.h"
#include "pins.h"
#include "secrets.h"

// ---------------------------------------------------------------- reporting
static int passed = 0, failed = 0, skipped = 0;
static String notes[12];
static int noteCount = 0;

static void report(const char *name, bool ok, const String &detail) {
  Serial.printf("  [%s] %-22s %s\n", ok ? "PASS" : "FAIL", name, detail.c_str());
  ok ? passed++ : failed++;
  if (!ok && noteCount < 12) notes[noteCount++] = String(name) + " — " + detail;
}

static void skip(const char *name, const String &why) {
  Serial.printf("  [SKIP] %-22s %s\n", name, why.c_str());
  skipped++;
}

// ------------------------------------------------------------------ 1 PSRAM
// Checked first because the camera cannot allocate a frame buffer without it,
// so a camera failure here is almost always really a PSRAM config failure.
static bool testPsram() {
  bool found = psramFound();
  size_t sz = found ? ESP.getPsramSize() : 0;
  report("PSRAM", found,
         found ? String(sz / 1024) + " KB available"
               : "not found — set board_build.arduino.memory_type = qio_opi");
  return found;
}

// ----------------------------------------------------------------- 2 camera
static bool testCamera(bool psramOk) {
  camera_config_t c = {};
  c.ledc_channel = LEDC_CHANNEL_0;
  c.ledc_timer   = LEDC_TIMER_0;
  c.pin_d0 = Y2_GPIO_NUM;  c.pin_d1 = Y3_GPIO_NUM;
  c.pin_d2 = Y4_GPIO_NUM;  c.pin_d3 = Y5_GPIO_NUM;
  c.pin_d4 = Y6_GPIO_NUM;  c.pin_d5 = Y7_GPIO_NUM;
  c.pin_d6 = Y8_GPIO_NUM;  c.pin_d7 = Y9_GPIO_NUM;
  c.pin_xclk = XCLK_GPIO_NUM;   c.pin_pclk  = PCLK_GPIO_NUM;
  c.pin_vsync = VSYNC_GPIO_NUM; c.pin_href  = HREF_GPIO_NUM;
  c.pin_sscb_sda = SIOD_GPIO_NUM; c.pin_sscb_scl = SIOC_GPIO_NUM;
  c.pin_pwdn = PWDN_GPIO_NUM;   c.pin_reset = RESET_GPIO_NUM;
  c.xclk_freq_hz = 20000000;
  c.pixel_format = PIXFORMAT_JPEG;
  c.frame_size = psramOk ? FRAMESIZE_VGA : FRAMESIZE_QVGA;
  c.jpeg_quality = 12;
  c.fb_count = psramOk ? 2 : 1;

  esp_err_t err = esp_camera_init(&c);
  if (err != ESP_OK) {
    report("Camera init", false,
           "error 0x" + String(err, HEX) + " — check the ribbon latch");
    return false;
  }
  report("Camera init", true, "OK");
  return true;
}

// A frame that is suspiciously small is usually a lens cap, a dark room, or a
// half-seated ribbon — all of which init fine and then produce nothing useful.
static void testCapture() {
  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    report("Camera capture", false, "returned no frame");
    return;
  }
  size_t len = fb->len;
  esp_camera_fb_return(fb);
  report("Camera capture", len > 1000,
         String(len) + " bytes" +
         (len > 1000 ? "" : " — too small, is the lens covered?"));
}

// ----------------------------------------------------------------- 3 button
// Interactive: waits for a real press, so it proves the whole path from the
// physical switch through the wiring to the pin.
static void testButton() {
#if USE_PUSH_BUTTON
  pinMode(PIN_TRIGGER, INPUT_PULLUP);
  delay(50);

  if (digitalRead(PIN_TRIGGER) == LOW) {
    report("Button idle state", false,
           "reads LOW with nothing pressed — the two legs you used are "
           "internally joined, or a wire is shorted to GND");
    return;
  }
  report("Button idle state", true, "HIGH as expected");

  Serial.println("\n  >>> PRESS THE BUTTON NOW (8 seconds) <<<\n");
  unsigned long deadline = millis() + 8000;
  int presses = 0;
  bool down = false;
  while (millis() < deadline) {
    bool nowDown = (digitalRead(PIN_TRIGGER) == LOW);
    if (nowDown && !down) { presses++; Serial.println("      press detected"); }
    down = nowDown;
    delay(15);   // crude debounce, plenty for a human finger
  }
  report("Button press", presses > 0,
         presses > 0 ? String(presses) + " press(es) seen"
                     : "nothing detected — check the leg pair and the GND wire");
#else
  skip("Button", "USE_PUSH_BUTTON is 0 — touch pad build");
#endif
}

// ------------------------------------------------------------------ 4 audio
// Generates a tone directly rather than decoding MP3, so a failure here means
// the amp or its wiring, not the decoder or the network.
static void testAudio() {
  AudioOutputI2S *out = new AudioOutputI2S();
  out->SetPinout(PIN_I2S_BCLK, PIN_I2S_LRC, PIN_I2S_DIN);
  out->SetBitsPerSample(16);
  out->SetChannels(2);
  out->SetRate(16000);
  out->SetGain(0.6);

  if (!out->begin()) {
    report("I2S output", false, "begin() failed — check BCLK/LRC/DIN wiring");
    delete out;
    return;
  }
  report("I2S output", true, "started");

  Serial.println("\n  >>> LISTEN: two seconds of tone should play <<<\n");
  const float freq = 440.0f;      // A4 — easy to recognise as a real note
  const int   rate = 16000;
  for (int i = 0; i < rate * 2; i++) {
    int16_t v = (int16_t)(8000.0f * sinf(2.0f * PI * freq * i / rate));
    int16_t frame[2] = {v, v};
    while (!out->ConsumeSample(frame)) delay(1);
  }
  out->stop();
  delete out;

  report("Tone played", true, "if you heard nothing, see the notes below");
}

// ------------------------------------------------------------------- 5 wifi
static bool testWifi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long deadline = millis() + 15000;
  while (WiFi.status() != WL_CONNECTED && millis() < deadline) delay(250);

  bool ok = (WiFi.status() == WL_CONNECTED);
  report("WiFi", ok,
         ok ? "connected, IP " + WiFi.localIP().toString()
            : "failed — wrong password, or a 5GHz-only network (needs 2.4GHz)");
  return ok;
}

// ----------------------------------------------------------------- 6 server
static void testServer(bool wifiOk) {
  if (!wifiOk) { skip("Server reachable", "no WiFi"); return; }

  HTTPClient http;
  String url = String("http://") + SERVER_HOST + ":" + SERVER_PORT + "/health";
  http.setTimeout(5000);
  http.begin(url);
  int code = http.GET();
  String body = (code > 0) ? http.getString() : "";
  http.end();

  report("Server reachable", code == 200,
         code == 200
           ? "200 OK from " + String(SERVER_HOST) + " — " + body
           : "no answer (code " + String(code) + ") — is uvicorn running, is "
             "SERVER_HOST right, are laptop and board on the same network?");
}

// -------------------------------------------------------------------- setup
void setup() {
  Serial.begin(115200);
  delay(2500);   // give the USB serial port time to attach before printing

  Serial.println("\n\n=======================================");
  Serial.println(" VOCALENS SELF-TEST");
  Serial.println("=======================================\n");

  bool psramOk = testPsram();
  bool camOk   = testCamera(psramOk);
  if (camOk) testCapture(); else skip("Camera capture", "init failed");
  testButton();
  testAudio();
  bool wifiOk = testWifi();
  testServer(wifiOk);

  Serial.println("\n---------------------------------------");
  Serial.printf(" %d passed, %d failed, %d skipped\n", passed, failed, skipped);
  Serial.println("---------------------------------------");

  if (failed == 0) {
    Serial.println("\n All checks passed. Flash the main firmware:");
    Serial.println("   pio run -t upload\n");
  } else {
    Serial.println("\n Fix these IN ORDER — the first failure often causes");
    Serial.println(" the ones below it:\n");
    for (int i = 0; i < noteCount; i++)
      Serial.printf("   %d. %s\n", i + 1, notes[i].c_str());
    Serial.println();
  }

  Serial.println(" Heard no tone but 'Tone played' passed?");
  Serial.println("   - an SD / SHUTDOWN pin on the amp is pulled low");
  Serial.println("   - amp VIN has no power (meter it against GND)");
  Serial.println("   - speaker not connected to the amp outputs");
  Serial.println(" Tone was loud static instead of a clean note?");
  Serial.println("   - BCLK and LRC are swapped (D8 -> BCLK, D9 -> LRC)\n");
}

void loop() {
  delay(10000);
}
