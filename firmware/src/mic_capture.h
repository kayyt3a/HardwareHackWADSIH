// Records a few seconds of PCM audio from the onboard PDM mic into a PSRAM
// buffer after a trigger fires (wake word or touch pad), so the spoken
// question ("what does this say?", "what colour is this?", ...) can be sent
// to the server alongside the photo. Uses the ESP32 I2S driver in PDM RX
// mode against the Sense board's onboard mic pins.
#pragma once

#include <Arduino.h>
#include <driver/i2s.h>

static const int MIC_SAMPLE_RATE = 16000;
static const int MIC_RECORD_SECONDS = 4;
static const size_t MIC_BUFFER_BYTES = MIC_SAMPLE_RATE * 2 * MIC_RECORD_SECONDS; // 16-bit mono

inline void setupMic() {
  // TODO: configure i2s_driver_install() for PDM RX on the Sense board's
  // onboard mic pins (fixed by the board, see Seeed's XIAO ESP32S3 Sense
  // schematic — not user-assignable like the peripherals in pins.h).
}

// Blocks for MIC_RECORD_SECONDS while filling buf (caller allocates via
// ps_malloc(MIC_BUFFER_BYTES)). Returns bytes actually captured.
inline size_t recordQuestion(uint8_t *buf) {
  // TODO: i2s_read() loop into buf until MIC_BUFFER_BYTES filled or a
  // simple silence/energy-based end-of-speech check trips early.
  Serial.println("[mic] recordQuestion() not yet implemented — stub");
  return 0;
}
