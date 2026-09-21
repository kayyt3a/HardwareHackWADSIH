// Records a few seconds of PCM audio from the onboard PDM mic into a PSRAM
// buffer after a trigger fires (wake word or touch pad), so the spoken
// question ("what does this say?", "what colour is this?", ...) can be sent
// to the server alongside the photo. Uses the ESP32 I2S driver in PDM RX
// mode against the Sense board's onboard mic pins.
//
// Bare samples, no WAV header: the server detects the missing RIFF magic
// and wraps them at MIC_SAMPLE_RATE before transcription. Keep this rate
// and the server's pcm.TARGET_RATE the same or the audio transcribes as
// gibberish while still sounding fine on a level meter.
#pragma once

#include <Arduino.h>
#include <driver/i2s.h>
#include <math.h>
#include <string.h>

static const int MIC_SAMPLE_RATE = 16000;

// BENCH: recording runs until you press Enter in the Serial Monitor, so this
// is only the ceiling — the buffer it can't record past. 15s of 16-bit mono
// is 480 KB, against 8 MB of PSRAM.
static const int MIC_MAX_SECONDS = 15;
static const size_t MIC_BUFFER_BYTES = MIC_SAMPLE_RATE * 2 * MIC_MAX_SECONDS; // 16-bit mono

// One i2s_read at a time, so Enter is noticed within about this long.
static const size_t MIC_CHUNK_BYTES = MIC_SAMPLE_RATE * 2 / 10;  // 100ms

// End of speech: how long the room has to go quiet again before the
// recording stops on its own. Long enough to survive the pause in the
// middle of a sentence, short enough not to feel like a wait.
static const uint32_t MIC_SILENCE_MS = 1000;

// How much louder than the room's own floor a chunk has to be to count as
// speech, and how far back down it has to fall to count as quiet again. A
// ratio, not a level, so it holds in a quiet room and a loud one without
// being re-tuned — the same reasoning as the server's normalise().
//
// Two different numbers on purpose. With one, ordinary room noise sitting
// near the threshold flickers across it and every flicker looks like more
// speech, so the recording never ends and runs to the ceiling. Speech has
// to clearly exceed SPEECH, and silence has to clearly fall below QUIET.
static const float MIC_SPEECH_RATIO = 4.0f;
static const float MIC_QUIET_RATIO = 2.0f;

// The floor follows the quietest chunk down immediately but is only allowed
// to creep back up. Without the creep, one unusually quiet moment pins the
// floor near zero for the rest of the recording, every threshold derived
// from it collapses, and the room itself reads as speech forever.
static const float MIC_FLOOR_RISE = 1.05f;  // per 100ms chunk

// If nothing that sounds like speech ever arrives, give up after this
// instead of holding the wearer for the full MIC_MAX_SECONDS.
static const uint32_t MIC_NO_SPEECH_MS = 6000;

// Kept either side of the speech when the recording is trimmed. Enough not
// to clip the start of the first word or the tail of the last one.
static const uint32_t MIC_KEEP_BEFORE_MS = 200;
static const uint32_t MIC_KEEP_AFTER_MS = 400;

// Chunks at the start whose level is ignored while the DMA settles — the
// same start-up transient the server skips when it measures.
static const int MIC_LEADIN_CHUNKS = 3;

// Nothing can end a recording before this. Both stop paths can fire the
// instant recording starts — a touch pad still settling after the press
// that triggered it, or a byte the serial monitor sends on connect — and
// the symptom is a recording that ends before you have drawn breath.
static const uint32_t MIC_MIN_MS = 1000;

// Let a second press of the trigger end the recording. Off by default: on a
// touch pad, a threshold that is even slightly low reads the press that
// STARTED the recording as the one ending it, and the recording dies
// immediately. Turn it on once the pad is calibrated (run the selftest
// build) and you want to record without a keyboard.
#ifndef MIC_STOP_ON_TRIGGER
#define MIC_STOP_ON_TRIGGER 0
#endif

// Signature of the "do this while the mic is live" callback — the camera
// capture, so the photo is taken during the question rather than before it.
typedef void (*MicDuringCallback)(void *ctx);

// Signature of the "should I stop now?" callback, polled between reads.
// main.cpp passes one that watches for a second press of the trigger, so
// the recording can be ended without a keyboard.
typedef bool (*MicStopCheck)(void *ctx);

// Fixed by the Sense board's own wiring — see Seeed's XIAO ESP32S3 Sense
// schematic. Not user-assignable like the peripherals in pins.h, and nothing
// else may use them while the mic is up.
static const int MIC_CLK_PIN = 42;
static const int MIC_DATA_PIN = 41;

// I2S unit 0. The speaker has unit 1 (see audio_playback.cpp), so mic-in and
// speaker-out don't collide; the camera is on LCD_CAM and touches neither.
static bool micReady = false;

inline void setupMic() {
  if (micReady) return;

  i2s_config_t config = {};
  config.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX | I2S_MODE_PDM);
  config.sample_rate = MIC_SAMPLE_RATE;
  config.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  // A single PDM mic. ONLY_LEFT gives packed mono samples rather than a
  // stereo stream with every second sample empty.
  config.channel_format = I2S_CHANNEL_FMT_ONLY_LEFT;
  config.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  config.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  // 16 x 512 frames = 8192 samples = 512ms of audio in flight. Deeper than
  // the usual 8 because the read loop stalls while the camera grabs a frame,
  // and anything the DMA can't hold during that stall is lost from the
  // middle of the recording.
  config.dma_buf_count = 16;
  config.dma_buf_len = 512;
  config.use_apll = false;
  config.tx_desc_auto_clear = false;
  config.fixed_mclk = 0;

  esp_err_t err = i2s_driver_install(I2S_NUM_0, &config, 0, nullptr);
  if (err != ESP_OK) {
    Serial.printf("[MIC] driver install failed: 0x%x (%s)\n", err,
                  esp_err_to_name(err));
    return;
  }

  // PDM has no bit clock: the mic's clock rides on WS, data comes back on DIN.
  i2s_pin_config_t pins = {};
  pins.mck_io_num = I2S_PIN_NO_CHANGE;
  pins.bck_io_num = I2S_PIN_NO_CHANGE;
  pins.ws_io_num = MIC_CLK_PIN;
  pins.data_out_num = I2S_PIN_NO_CHANGE;
  pins.data_in_num = MIC_DATA_PIN;

  err = i2s_set_pin(I2S_NUM_0, &pins);
  if (err != ESP_OK) {
    Serial.printf("[MIC] set_pin failed: 0x%x (%s)\n", err, esp_err_to_name(err));
    i2s_driver_uninstall(I2S_NUM_0);
    return;
  }

  // Matches the driver default; stated so the clock ratio isn't a mystery.
  i2s_set_pdm_rx_down_sample(I2S_NUM_0, I2S_PDM_DSR_8S);

  Serial.printf("[MIC] init OK — %d Hz, 16-bit mono, clk=%d din=%d, %ds max\n",
                MIC_SAMPLE_RATE, MIC_CLK_PIN, MIC_DATA_PIN, MIC_MAX_SECONDS);
  micReady = true;
}

// True once ANYTHING has arrived on the serial port.
//
// Deliberately not "a newline": the Arduino IDE's Serial Monitor sends no
// line ending at all unless its dropdown is set to one, so a version that
// waits for \n silently never stops for half the people who try it, and
// looks like the recording ignoring them. Any keystroke ends it, Enter
// included, whatever the line-ending setting is.
inline bool micSerialInput() {
  bool got = false;
  while (Serial.available()) {
    Serial.read();
    got = true;
  }
  return got;
}

// Loudest 20ms inside a chunk, as RMS about its own mean. The mean is the
// mic's DC offset, which is large and roughly constant; the deviation from
// it is the sound.
//
// The loudest sub-window rather than the whole chunk's RMS, because speech
// is bursts with gaps: averaged over 100ms a real word measures barely above
// the room, and a test recording that plainly contains speech never trips
// the threshold. Same 20ms window the server measures with.
static const size_t MIC_SUB_SAMPLES = MIC_SAMPLE_RATE / 50;  // 20ms

inline float micChunkLevel(const int16_t *s, size_t count) {
  float best = 0.0f;
  for (size_t at = 0; at + MIC_SUB_SAMPLES <= count; at += MIC_SUB_SAMPLES) {
    int64_t sum = 0;
    for (size_t i = 0; i < MIC_SUB_SAMPLES; i++) sum += s[at + i];
    const float mean = (float)sum / (float)MIC_SUB_SAMPLES;
    double acc = 0.0;
    for (size_t i = 0; i < MIC_SUB_SAMPLES; i++) {
      const double d = s[at + i] - mean;
      acc += d * d;
    }
    const float rms = (float)sqrt(acc / (double)MIC_SUB_SAMPLES);
    if (rms > best) best = rms;
  }
  return best;
}

// Records until you press Enter in the Serial Monitor (or type anything at
// all), until `stop` says so, or until the buffer is full at MIC_MAX_SECONDS.
// Caller allocates buf via ps_malloc(MIC_BUFFER_BYTES). Returns bytes
// actually captured.
//
// `during` is called once, shortly after the first samples land, and is where
// the camera capture goes: the mic is already running when the photo is taken,
// so the two overlap instead of the recording finishing first. The read loop
// is stalled for however long the callback takes — see the DMA depth note in
// setupMic().
inline size_t recordQuestion(uint8_t *buf, MicDuringCallback during = nullptr,
                             void *ctx = nullptr, MicStopCheck stop = nullptr,
                             void *stopCtx = nullptr) {
  if (!micReady) {
    Serial.println("[MIC] not initialised — call setupMic() in setup()");
    return 0;
  }
  if (!buf) return 0;

  // The first reads after a long idle hand back whatever was sitting in the
  // DMA buffers, which is stale audio from before the press. Clear them so
  // the recording starts at the press, not half a second earlier.
  i2s_zero_dma_buffer(I2S_NUM_0);

  // Drop anything already typed, so a leftover newline from the last
  // recording doesn't end this one immediately.
  while (Serial.available()) Serial.read();

  Serial.printf("[MIC] recording — speak now. Stops %ums after you finish, "
                "or on a keypress here. Max %ds.\n",
                (unsigned)MIC_SILENCE_MS, MIC_MAX_SECONDS);
  const uint32_t started = millis();

  size_t filled = 0;
  int emptyTries = 0;
  bool ranDuring = false;
  bool stoppedEarly = false;

  // End-of-speech tracking. The floor is the quietest chunk seen so far,
  // which is the room with nobody talking; everything is judged against it
  // rather than against a fixed number.
  float floorLevel = 0.0f;
  bool floorSet = false;
  bool speechSeen = false;
  int chunkIndex = 0;
  uint32_t quietSince = 0;

  // Byte offsets of the first and last chunk that contained speech, so the
  // silence either side can be dropped before upload. Every byte trimmed is
  // a byte not sent over WiFi and not handed to the transcriber, both of
  // which are on the path between the question and the answer.
  size_t speechStart = 0;
  size_t speechEnd = 0;

  while (filled < MIC_BUFFER_BYTES) {
    size_t want = MIC_BUFFER_BYTES - filled;
    if (want > MIC_CHUNK_BYTES) want = MIC_CHUNK_BYTES;

    size_t got = 0;
    esp_err_t err = i2s_read(I2S_NUM_0, buf + filled, want, &got,
                             pdMS_TO_TICKS(500));
    if (err != ESP_OK) {
      Serial.printf("[MIC] read failed at %u/%u bytes: 0x%x (%s)\n",
                    (unsigned)filled, (unsigned)MIC_BUFFER_BYTES, err,
                    esp_err_to_name(err));
      break;
    }
    if (got == 0) {
      // A timeout, not an error: the driver is alive but nothing is
      // arriving. A short recording is still worth sending, so give up
      // rather than blocking the press forever.
      if (++emptyTries >= 4) {
        Serial.printf("[MIC] no data at %u/%u bytes — stopping\n",
                      (unsigned)filled, (unsigned)MIC_BUFFER_BYTES);
        break;
      }
      continue;
    }
    emptyTries = 0;
    filled += got;

    // --- end of speech ---------------------------------------------------
    const size_t chunkSamples = got / sizeof(int16_t);
    const float level = micChunkLevel((const int16_t *)(buf + filled - got),
                                      chunkSamples);
    if (chunkIndex++ >= MIC_LEADIN_CHUNKS) {
      if (!floorSet) {
        floorLevel = level;
        floorSet = true;
      } else {
        const float crept = floorLevel * MIC_FLOOR_RISE + 0.5f;
        floorLevel = (level < crept) ? level : crept;
      }

      const float speechLevel = floorLevel * MIC_SPEECH_RATIO + 8.0f;
      const float quietLevel = floorLevel * MIC_QUIET_RATIO + 4.0f;

      if (level > speechLevel) {
        if (!speechSeen) speechStart = filled - got;
        speechSeen = true;
        speechEnd = filled;
        quietSince = 0;
      } else if (speechSeen && level < quietLevel) {
        if (!quietSince) quietSince = millis();
        if (millis() - quietSince >= MIC_SILENCE_MS &&
            millis() - started >= MIC_MIN_MS) {
          Serial.printf("[MIC] stopped after %ums — %ums of quiet (level %.0f, "
                        "floor %.0f)\n", (unsigned)(millis() - started),
                        (unsigned)MIC_SILENCE_MS, level, floorLevel);
          stoppedEarly = true;
          break;
        }
      }
    }

    if (!speechSeen && millis() - started >= MIC_NO_SPEECH_MS) {
      Serial.printf("[MIC] stopped after %ums — nothing above the room's floor "
                    "(%.0f). Say something louder, or check the mic.\n",
                    (unsigned)(millis() - started), floorLevel);
      stoppedEarly = true;
      break;
    }

    // Take the photo once the mic is demonstrably running, not before.
    if (!ranDuring && during) {
      during(ctx);
      ranDuring = true;
    }

    const uint32_t elapsed = millis() - started;

    // Poll both stop paths even inside the guard window, so whatever they
    // have queued up is consumed rather than firing the moment it lifts.
    const bool keyed = micSerialInput();
    const bool triggered = (MIC_STOP_ON_TRIGGER && stop) ? stop(stopCtx) : false;

    if (elapsed >= MIC_MIN_MS) {
      if (keyed) {
        Serial.printf("[MIC] stopped after %ums — keypress\n", (unsigned)elapsed);
        stoppedEarly = true;
        break;
      }
      if (triggered) {
        Serial.printf("[MIC] stopped after %ums — trigger pressed again\n",
                      (unsigned)elapsed);
        stoppedEarly = true;
        break;
      }
    }
  }

  if (!ranDuring && during) during(ctx);  // buffer filled on the first read
  if (!stoppedEarly && filled >= MIC_BUFFER_BYTES) {
    Serial.printf("[MIC] hit the %ds ceiling — raise MIC_MAX_SECONDS if that cut you off\n",
                  MIC_MAX_SECONDS);
  }

  // Drop the silence either side of the speech. The lead-in is the DMA
  // settling and the tail is the pause that ended the recording; neither
  // carries a word, and both cost upload time and transcription time.
  if (speechSeen && speechEnd > speechStart) {
    const size_t before = (size_t)MIC_SAMPLE_RATE * 2 * MIC_KEEP_BEFORE_MS / 1000;
    const size_t after = (size_t)MIC_SAMPLE_RATE * 2 * MIC_KEEP_AFTER_MS / 1000;

    size_t from = (speechStart > before) ? speechStart - before : 0;
    from &= ~(size_t)1;  // stay on a sample boundary
    size_t to = speechEnd + after;
    if (to > filled) to = filled;

    if (to > from && (from > 0 || to < filled)) {
      const size_t kept = to - from;
      if (from > 0) memmove(buf, buf + from, kept);
      Serial.printf("[MIC] trimmed %.1fs of silence — %u bytes to send\n",
                    (double)(filled - kept) / (MIC_SAMPLE_RATE * 2),
                    (unsigned)kept);
      filled = kept;
    }
  }

  // Peak level over the recording, DC offset removed — PDM samples sit a
  // constant amount away from zero. This is the one number that says whether
  // the mic heard anything, without leaving the board: under about 300 is a
  // quiet room, speech should be well into the thousands. Cheap insurance
  // against chasing a transcription bug that is really a dead mic.
  const size_t count = filled / sizeof(int16_t);
  int32_t peak = 0;
  if (count) {
    const int16_t *s = (const int16_t *)buf;
    int64_t sum = 0;
    for (size_t i = 0; i < count; i++) sum += s[i];
    const int32_t dc = (int32_t)(sum / (int64_t)count);
    for (size_t i = 0; i < count; i++) {
      int32_t v = s[i] - dc;
      if (v < 0) v = -v;
      if (v > peak) peak = v;
    }
  }

  Serial.printf("[MIC] captured %u bytes (%.1fs) in %ums, peak %ld%s\n",
                (unsigned)filled, (double)count / MIC_SAMPLE_RATE,
                (unsigned)(millis() - started), (long)peak,
                peak < 300 ? "  <- near silence, did it hear you?" : "");
  return filled;
}

// The recording now ends by itself when the talking stops, which is what a
// wearer needs — no keyboard, no second press. The keypress is kept as the
// bench override, and MIC_STOP_ON_TRIGGER as the option for a calibrated pad.
