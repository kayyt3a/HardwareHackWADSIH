// Vocalens firmware — glasses form factor, XIAO ESP32S3 Sense
//
// Trigger: a press on the temple — a touch pad or a push button, see
// USE_PUSH_BUTTON in pins.h. On trigger: capture a JPEG frame, POST it to
// the server, and play the answer that comes back through a
// bone-conduction transducer.
//
// The answer arrives as RAW PCM — 16 kHz, 16-bit signed little-endian,
// mono — and goes straight to the I2S DAC. There is no audio decoder on
// the device and no audio library in the build; see audio_playback.cpp.
//
// NOT FINISHED YET — each is compiled in but switched off by a define
// below, so turning one on is a one-line change:
//  - The mic (mic_capture.h). No spoken question is sent yet; it's typed
//    into the server's terminal while the photo uploads.
//  - Wake-word detection (wake_word.h), which needs ESP-SR. The press is
//    the only trigger.
//  - The offline barcode fallback (offline_fallback.h). With no network a
//    press just says so.
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

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include "esp_camera.h"
#include "pins.h"
#include "secrets.h"
#include "mic_capture.h"
#include "offline_fallback.h"
#include "wake_word.h"


// FEATURE SWITCHES — all three are written but not finished, so they are
// compiled in and left switched off rather than deleted. Flip one to 1 when
// its header does something real; nothing else in this file needs changing.
//
//   MIC      — implemented. On, the press records MIC_RECORD_SECONDS of
//              PDM audio and sends it with the photo; the server saves it
//              to questions/ and transcribes it. Off, this skips the 128 KB
//              PSRAM allocation and the empty audio part on every press.
//   WAKEWORD — isWakeWordDetected() in wake_word.h always returns false,
//              pending ESP-SR. Off, the pad is the only trigger.
//   OFFLINE  — handleOfflineFallback() in offline_fallback.h only prints a
//              message. On, a press with no network tries a local barcode
//              decode instead of giving up.
#define MIC_ENABLED 1
#define WAKEWORD_ENABLED 0
#define OFFLINE_FALLBACK_ENABLED 0

bool wifiConnected = false;

void setupWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  wifiConnected = (WiFi.status() == WL_CONNECTED);
  if (wifiConnected) {
    Serial.println("\nWiFi connected");
  } else {
    // Print the specific reason instead of just "failed" — the numeric code
    // narrows down what's actually wrong:
    //   1 = WL_NO_SSID_AVAIL      -> network name not found/visible at all
    //                                (classic sign of a 5GHz-only network,
    //                                 since the ESP32-S3 can't see 5GHz)
    //   4 = WL_CONNECT_FAILED     -> usually a wrong password
    //   6 = WL_DISCONNECTED       -> found the network but didn't associate
    //   0 = WL_IDLE_STATUS        -> never really tried (rare)
    Serial.printf("\nWiFi FAILED — offline mode (status code %d)\n", WiFi.status());
  }
}

// One TLS connection, kept open and reused for every request. Opening a new
// HTTPS connection costs the ESP32 1-3 s of handshake; reusing it costs
// nothing. keepServerWarm() pings /health while idle so the connection is
// still open when the pad is pressed.
WiFiClientSecure serverClient;
// Created once and never destroyed. HTTPClient's destructor calls stop() on
// its connection, so a local HTTPClient hung up at the end of every request
// and nothing was ever reused.
HTTPClient serverHttp;
unsigned long lastServerContact = 0;
const unsigned long KEEPALIVE_MS = 20000;

void keepServerWarm() {
  if (WiFi.status() != WL_CONNECTED) return;
  // Time-based on purpose: if the server is unreachable, retrying every loop
  // would block the pad for the whole timeout, over and over.
  if (lastServerContact != 0 && millis() - lastServerContact < KEEPALIVE_MS) return;
  HTTPClient &http = serverHttp;
  http.setReuse(true);
  http.setTimeout(8000);
  http.begin(serverClient, String("https://") + SERVER_HOST + "/health");
  bool wasOpen = serverClient.connected();
  int code = http.GET();
  if (code > 0) http.getString();   // drain so the connection can be reused
  http.end();
  Serial.printf("[NET] keep-alive ping: %d, connection was %s, now %s\n", code,
                wasOpen ? "open" : "closed", serverClient.connected() ? "open" : "closed");
  if (code != 200) serverClient.stop();
  lastServerContact = millis();
}

// Opens the TLS connection on the other CPU core while the wearer is still
// speaking, so the 1-3 s handshake overlaps the recording instead of adding
// to the wait afterwards. It has to be the other core: on this one the
// handshake would block the mic and drop audio.
static volatile bool warmConnectDone = true;

static void warmConnectTask(void *) {
  unsigned long t = millis();
  int ok = serverClient.connect(SERVER_HOST, 443);
  Serial.printf("[NET] early connect %s in %lums\n", ok ? "OK" : "FAILED", millis() - t);
  warmConnectDone = true;
  vTaskDelete(nullptr);
}

void startWarmConnect() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[NET] early connect skipped: WiFi down");
    return;
  }
  if (serverClient.connected()) {
    Serial.println("[NET] connection still open from last time");
    return;
  }
  warmConnectDone = false;
  // 12 kB stack: the TLS handshake needs far more than the default.
  if (xTaskCreatePinnedToCore(warmConnectTask, "warmConnect", 12288, nullptr,
                              1, nullptr, 0) != pdPASS) {
    warmConnectDone = true;   // couldn't start it; the request connects itself
  }
}

void waitWarmConnect() {
  unsigned long started = millis();
  while (!warmConnectDone && millis() - started < 10000) delay(5);
}

// Called on every press. On battery the board often boots before the phone
// hotspot is up, so the boot-time attempt in setupWiFi() fails. Without
// this, that one failure left the board offline until it was power-cycled.
bool ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    return true;
  }
  Serial.print("WiFi down — reconnecting");
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  for (int i = 0; i < 20 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }
  wifiConnected = (WiFi.status() == WL_CONNECTED);
  Serial.println(wifiConnected ? " connected" : " failed");
  return wifiConnected;
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
  config.frame_size = FRAMESIZE_SVGA; // 800x600 — one preset step down from
                                      // XGA (1024x768), about 39% fewer
                                      // pixels and so a markedly smaller
                                      // POST body
  // Lower = less compression = crisper fine text, but a bigger JPEG and so
  // a bigger POST body. 6 -> 7 is roughly 5% off the encoded size at
  // effectively no cost to legibility; go much past 10 and small print on a
  // label starts to smear.
  config.jpeg_quality = 7;
  config.fb_count = psramFound() ? 2 : 1;
  // Without this, fb_count > 1 defaults to FIFO ("grab when empty") —
  // esp_camera_fb_get() then returns the OLDEST buffered frame, which can be
  // stale by tens of seconds if the driver's been filling the queue while
  // idle between triggers. CAMERA_GRAB_LATEST always returns the newest
  // frame instead, discarding anything older.
  config.grab_mode = CAMERA_GRAB_LATEST;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }

  // Correct sensor orientation in software (see pins.h for how to tune).
  sensor_t *sensor = esp_camera_sensor_get();
  if (sensor) {
    sensor->set_vflip(sensor, CAMERA_VFLIP);
    sensor->set_hmirror(sensor, CAMERA_HMIRROR);
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
float touchBaseline = 0;

// Averages the untouched reading at power-on (~0.5 s). Don't touch the pad
// during it; if you do, the drift tracking in manualTriggered() recovers.
void calibrateTouch() {
#if !USE_PUSH_BUTTON
  uint64_t sum = 0;
  const int n = 25;
  for (int i = 0; i < n; i++) {
    sum += touchRead(PIN_TRIGGER);
    delay(20);
  }
  touchBaseline = (float)sum / n;
  Serial.printf("[PAD] baseline %.0f, touch above %.0f (+%d%%)\n", touchBaseline,
                touchBaseline * (100 + TOUCH_RISE_PERCENT) / 100.0f, TOUCH_RISE_PERCENT);
#endif
}

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
  // Compared against the baseline measured at boot, not a fixed number:
  // readings shift between USB and battery power. See calibrateTouch().
  uint32_t v = touchRead(PIN_TRIGGER);
  float limit = touchBaseline * (100.0f + TOUCH_RISE_PERCENT) / 100.0f;
  float limitLow = touchBaseline * (100.0f - TOUCH_RISE_PERCENT) / 100.0f;
#if TOUCH_ACTIVE_HIGH
  bool touched = v > limit;
#else
  bool touched = v < limitLow;
#endif
  // Follow slow drift (temperature, humidity, a touch held at power-on)
  // while untouched, so the baseline corrects itself within a few seconds.
  if (!touched) touchBaseline = touchBaseline * 0.995f + v * 0.005f;
  return touched;
#endif
}

// Implemented in audio_playback.cpp. The server returns raw 16 kHz mono
// 16-bit PCM, so there is no decoding step — see that file for the I2S setup.
void setupSpeaker();
void playPcmStream(WiFiClient *stream, int contentLength);

// POSTs the JPEG frame to /ask as multipart/form-data and plays the PCM
// answer that comes back. Multipart is built manually since HTTPClient
// doesn't provide a helper for it.
// Grabs one frame. The camera driver keeps capturing continuously even while
// idle between triggers, so after a long gap the first frame handed back can
// be a stale one from the buffer queue. One throwaway flushes it; with
// CAMERA_GRAB_LATEST and fb_count = 2 a second adds only latency.
static camera_fb_t *grabFrame() {
  camera_fb_t *warmup = esp_camera_fb_get();
  if (warmup) {
    esp_camera_fb_return(warmup);
  }
  delay(50);
  return esp_camera_fb_get();
}

#if MIC_ENABLED
// Handed to recordQuestion() so the photo is taken WHILE the question is
// being recorded, rather than after the recording ends. Without this the
// wearer speaks, waits, and only then does the camera fire — which also
// means the frame shows wherever they had drifted to by the end.
static void grabFrameDuringRecording(void *ctx) {
  *(camera_fb_t **)ctx = grabFrame();
}

// Ends the recording on a SECOND press of the trigger. The pad that started
// it is usually still held when recording begins, so a press only counts
// once it has been released — the same edge-triggering loop() does, which is
// what stops one long touch reading as press after press.
static bool triggerPressedAgain(void *) {
  static bool released = false;
  if (!manualTriggered()) {
    released = true;
    return false;
  }
  if (released) {
    released = false;  // ready for the next recording
    return true;
  }
  return false;
}
#endif

void captureAskAndSpeak() {
  camera_fb_t *fb = nullptr;
  startWarmConnect();   // handshake runs while the wearer speaks

#if MIC_ENABLED
  uint8_t *audioBuf = (uint8_t *)ps_malloc(MIC_BUFFER_BYTES);
  if (!audioBuf) {
    // Silent before: the press just took a photo with no recording, which
    // looks exactly like a mic that isn't working.
    Serial.printf("[MIC] no PSRAM for %u bytes — recording skipped\n",
                  (unsigned)MIC_BUFFER_BYTES);
  }
  // Records until Enter is pressed in the serial monitor; the frame is
  // captured partway through, via the callback.
  size_t audioLen = audioBuf ? recordQuestion(audioBuf, grabFrameDuringRecording,
                                              &fb, triggerPressedAgain, nullptr)
                             : 0;
#else
  uint8_t *audioBuf = nullptr;
  size_t audioLen = 0;
#endif

  const unsigned long tStop = millis();   // recording finished
  // Either the mic path never ran, or its capture failed — try once here.
  if (!fb) fb = grabFrame();
  if (!fb) {
    Serial.println("Camera capture failed");
    if (audioBuf) free(audioBuf);
    return;
  }

  if (!ensureWiFi()) {
#if OFFLINE_FALLBACK_ENABLED
    Serial.println("No WiFi — falling back to offline barcode scan");
    handleOfflineFallback(fb);
#else
    Serial.println("No WiFi — nothing to send to");
#endif
    esp_camera_fb_return(fb);
    if (audioBuf) free(audioBuf);
    return;
  }

  waitWarmConnect();
  HTTPClient &http = serverHttp;
  http.setReuse(true);
  String url = String("https://") + SERVER_HOST + "/ask";
  http.begin(serverClient, url);
  // 90 seconds. Vision plus speech takes several on its own, and on the
  // bench the server is also waiting on a typed question. The library's
  // default is far shorter. A timeout that fires early is invisible from
  // the server side — it logs a clean 200 while the glasses have already
  // hung up and play nothing.
  http.setTimeout(90000);

  // The server puts the plain-text answer in X-Spoken-Text alongside the
  // audio body. Collecting it costs nothing and doesn't consume the body,
  // so the monitor can show what was said as well as play it.
  const char *headerKeys[] = {"X-Spoken-Text"};
  http.collectHeaders(headerKeys, 1);

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

  const unsigned long tSend = millis();
  const bool reused = serverClient.connected();
  int httpCode = http.POST(body, totalLen);
  const unsigned long tReply = millis();
  Serial.printf("[TIME] prep %lums | connection %s | upload %u B + server wait %lums\n",
                tSend - tStop, reused ? "REUSED" : "NEW (handshake)",
                (unsigned)totalLen, tReply - tSend);
  free(body);
  esp_camera_fb_return(fb);
  if (audioBuf) free(audioBuf);

  if (httpCode == 200) {
    // The answer text comes back in a header, so printing it costs nothing
    // and doesn't consume the body — the MP3 is still there to play.
    String answerText = http.header("X-Spoken-Text");
    Serial.println("\n  ===== ANSWER =====");
    Serial.println("  " + answerText);
    Serial.println("  ===================\n");

    // Plays as soon as the body is buffered — no further trigger needed.
    // getSize() is the Content-Length: -1 means the server didn't send one
    // (chunked), which playPcmStream can't buffer and will refuse.
    int bodyLen = http.getSize();
    Serial.printf("Audio body: %d bytes\n", bodyLen);
    WiFiClient *stream = http.getStreamPtr();
    const unsigned long tPlay = millis();
    playPcmStream(stream, bodyLen);
    Serial.printf("[TIME] download+play %lums | stop-speaking -> reply arrived %lums\n",
                  millis() - tPlay, tReply - tStop);
  } else {
    Serial.printf("Server error: %d\n", httpCode);
  }
  http.end();
  // A failed or half-read reply can leave junk on the connection; start
  // clean next time rather than reuse it.
  if (httpCode != 200) serverClient.stop();
  lastServerContact = millis();
}

void setup() {
  Serial.begin(115200);
  calibrateTouch();

#if USE_PUSH_BUTTON
  // INPUT_PULLUP holds the pin HIGH through an internal resistor, so a plain
  // button shorting it to GND is the whole circuit — no external resistor, and
  // no floating pin reading random noise when nothing is pressed.
  pinMode(PIN_TRIGGER, INPUT_PULLUP);
#endif

  setupWiFi();
  serverClient.setInsecure();
  keepServerWarm();
  if (!setupCamera()) {
    Serial.println("Halting: camera required");
    while (true) delay(1000);
  }
#if WAKEWORD_ENABLED
  setupWakeWord();
#endif
#if MIC_ENABLED
  setupMic();
#endif
#if OFFLINE_FALLBACK_ENABLED
  setupOfflineFallback();
#endif
  setupSpeaker();
#if WAKEWORD_ENABLED
  Serial.println("Glasses ready — say the wake word or press the pad");
#else
  Serial.println("Glasses ready — press the pad");
#endif
}

void loop() {
  // Edge-triggered: only fires on a fresh touch (not-touched -> touched),
  // and won't fire again until the pad is released first. This matters more
  // than it might seem, because manualTriggered() is a simple level check
  // (true for as long as the reading is above threshold) — without this,
  // an uncalibrated/borderline threshold (or just a lingering touch during
  // the several-second capture+server round trip) causes it to keep
  // re-firing on its own every ~1 second, which is exactly the
  // "runs automatically" symptom.
  static bool wasTriggered = false;
#if WAKEWORD_ENABLED
  bool nowTriggered = isWakeWordDetected() || manualTriggered();
#else
  bool nowTriggered = manualTriggered();
#endif

  // A short blackout after each round trip. Releasing the pad takes a
  // moment, and a borderline threshold can read as a second press the
  // instant the first one finishes — which arrives at the server as two
  // captures of the same thing.
  static unsigned long ignoreUntil = 0;

  // Say so on every press, even one that gets ignored. Without this a press
  // inside the blackout window looks identical to a pad that didn't register
  // at all, and you can't tell which you are debugging.
  if (nowTriggered && !wasTriggered) {
    Serial.println("[PAD] pressed");
    if (millis() <= ignoreUntil) {
      Serial.printf("[PAD] ignored — %lums left of the post-capture blackout\n",
                    (unsigned long)(ignoreUntil - millis()));
    }
  }

  if (nowTriggered && !wasTriggered && millis() > ignoreUntil) {
    Serial.println("Triggered — capturing frame");
    captureAskAndSpeak();
    ignoreUntil = millis() + 1500;
  }
  wasTriggered = nowTriggered;
  if (!nowTriggered) keepServerWarm();
  delay(20);
}
