// Raw PCM playback straight to the I2S DAC.
//
// The server sends bare samples — 16 kHz, 16-bit signed little-endian,
// mono — so there is no decoder here at all: the bytes that arrive over
// WiFi are the bytes that go to the DAC. Chain: board -> DAC -> amp ->
// bone-conduction transducer.
//
// The response is downloaded WHOLE into PSRAM before a single sample is
// played. Streaming it into the DAC as it arrives is the obvious design
// and it stutters: 16 kHz 16-bit mono drains at 32 KB/s, the link doesn't
// reliably beat that, and the moment it doesn't the DMA runs dry mid-word.
// A reply is tens of KB against 8 MB of PSRAM, so buffering costs nothing.

#include <Arduino.h>
#include <WiFiClient.h>
#include <driver/i2s.h>
#include "pins.h"

// Must match the server: tts_openrouter.SAMPLE_RATE / pcm.TARGET_RATE.
// Change both ends together.
#define PCM_SAMPLE_RATE 16000

// Output level, 0.0-1.0, applied per sample. Deliberately low: the
// transducer sits against the wearer's head, so this is headphone-close
// listening, not room volume.
#ifndef AUDIO_GAIN
#define AUDIO_GAIN 0.06f
#endif

// Give up if no new bytes arrive for this long. A STALL timeout, not a
// total-duration one — a slow link that keeps delivering is survivable,
// a dead one isn't.
#define AUDIO_STALL_TIMEOUT_MS 10000

// Refuse a body bigger than this rather than trying to allocate it.
// 16 kHz * 2 bytes * 15 s.
#define AUDIO_MAX_BYTES (PCM_SAMPLE_RATE * 2 * 15)

static bool speakerReady = false;

void setupSpeaker() {
  if (speakerReady) return;

  i2s_config_t config = {};
  config.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
  config.sample_rate = PCM_SAMPLE_RATE;
  config.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  // Stereo frames. The DAC is stereo and the transducer hangs off one
  // channel of the amp, so each mono sample is written to both slots
  // rather than guessing which one is wired.
  config.channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT;
  config.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  config.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  config.dma_buf_count = 8;
  config.dma_buf_len = 256;
  config.use_apll = false;
  // On underrun, play silence rather than repeating the last buffer —
  // which would be a buzz that sounds like a hardware fault.
  config.tx_desc_auto_clear = true;
  config.fixed_mclk = 0;
  config.mclk_multiple = I2S_MCLK_MULTIPLE_256;

  // I2S_NUM_1: the onboard PDM mic owns I2S_NUM_0, so speaker and mic
  // don't collide.
  esp_err_t err = i2s_driver_install(I2S_NUM_1, &config, 0, nullptr);
  if (err != ESP_OK) {
    Serial.printf("[SPK] driver install failed: 0x%x\n", err);
    return;
  }

  i2s_pin_config_t pins = {};
  pins.mck_io_num = I2S_PIN_NO_CHANGE;  // DAC makes its own; SCK tied to GND
  pins.bck_io_num = PIN_I2S_BCLK;
  pins.ws_io_num = PIN_I2S_LRC;
  pins.data_out_num = PIN_I2S_DIN;
  pins.data_in_num = I2S_PIN_NO_CHANGE;

  err = i2s_set_pin(I2S_NUM_1, &pins);
  if (err != ESP_OK) {
    Serial.printf("[SPK] set_pin failed: 0x%x\n", err);
    i2s_driver_uninstall(I2S_NUM_1);
    return;
  }

  // i2s_driver_install() leaves the TX channel RUNNING, and a running
  // channel with nothing written to it keeps clocking out whatever the DMA
  // descriptors happen to hold — which off a cold boot is not silence.
  // With minutes between replies that is an audible buzz the whole time.
  // Zero the buffers and stop the channel; playPcmStream starts it again
  // only while there is audio for it.
  i2s_zero_dma_buffer(I2S_NUM_1);
  i2s_stop(I2S_NUM_1);

  Serial.printf("[SPK] ready — I2S1, bclk=%d lrc=%d din=%d, %d Hz, gain %.2f\n",
                PIN_I2S_BCLK, PIN_I2S_LRC, PIN_I2S_DIN, PCM_SAMPLE_RATE,
                (double)AUDIO_GAIN);
  speakerReady = true;
}

// Writes mono 16-bit samples out as stereo frames, applying the gain.
static void writeSamples(const int16_t *samples, size_t count) {
  static int16_t frame[128 * 2];
  size_t done = 0;

  while (done < count) {
    size_t n = count - done;
    if (n > 128) n = 128;
    for (size_t i = 0; i < n; i++) {
      int16_t s = (int16_t)(samples[done + i] * AUDIO_GAIN);
      frame[i * 2] = s;
      frame[i * 2 + 1] = s;
    }
    size_t written = 0;
    i2s_write(I2S_NUM_1, frame, n * 2 * sizeof(int16_t), &written,
              pdMS_TO_TICKS(500));
    done += n;
  }
}

void playPcmStream(WiFiClient *stream, int contentLength) {
  if (!speakerReady) {
    Serial.println("[SPK] not initialised — call setupSpeaker() in setup()");
    return;
  }
  if (contentLength <= 0 || contentLength > AUDIO_MAX_BYTES) {
    Serial.printf("[SPK] refusing %d byte body\n", contentLength);
    return;
  }

  uint8_t *buf = (uint8_t *)ps_malloc(contentLength);
  if (!buf) {
    Serial.printf("[SPK] no room for %d bytes\n", contentLength);
    return;
  }

  int got = 0;
  unsigned long lastData = millis();
  while (got < contentLength) {
    size_t avail = stream->available();
    if (!avail) {
      if (!stream->connected()) break;
      if (millis() - lastData > AUDIO_STALL_TIMEOUT_MS) {
        Serial.printf("[SPK] stalled at %d/%d bytes\n", got, contentLength);
        break;
      }
      delay(1);
      continue;
    }
    if (avail > (size_t)(contentLength - got)) avail = contentLength - got;
    int n = stream->readBytes(buf + got, avail);
    if (n > 0) {
      got += n;
      lastData = millis();
    }
  }

  // A short reply is better than none — play whatever arrived.
  size_t samples = got / sizeof(int16_t);
  if (!samples) {
    Serial.println("[SPK] no audio received");
    free(buf);
    return;
  }

  Serial.printf("[SPK] playing %u samples (%.1fs)\n", (unsigned)samples,
                (double)samples / PCM_SAMPLE_RATE);

  // Only clock the DAC while there is audio for it. See setupSpeaker().
  i2s_start(I2S_NUM_1);
  writeSamples((const int16_t *)buf, samples);
  i2s_zero_dma_buffer(I2S_NUM_1);
  i2s_stop(I2S_NUM_1);

  free(buf);
  Serial.println("[SPK] playback finished");
}
