// Offline fallback: when WiFi/server is unreachable, fall back to on-device
// barcode/QR decoding so the device still does *something* useful rather
// than failing silently. Barcode decoding from a raw JPEG frame typically
// needs a lightweight decoder such as quirc (QR) — not wired up yet, this
// is the integration point.
#pragma once

#include "esp_camera.h"

inline void setupOfflineFallback() {
  // TODO: init barcode/QR decoder library here if used
}

inline void handleOfflineFallback(camera_fb_t *fb) {
  // TODO: run barcode/QR decode on fb->buf / fb->len.
  // On success: look up in a small cached product table, or just announce
  // "barcode found, no internet connection to look it up" via a pre-recorded
  // audio clip stored on flash (LittleFS), since TTS also needs network in
  // the default OpenAI-backed config.
  Serial.println("[offline] No network — barcode fallback not yet implemented");
}
