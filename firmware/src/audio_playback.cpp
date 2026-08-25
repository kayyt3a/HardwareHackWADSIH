// MP3 playback over I2S using ESP8266Audio. Buffers the incoming HTTP
// response fully into PSRAM before playback for simplicity — fine for the
// short (few-second) responses this device produces. A true streaming
// player (AudioFileSourceHTTPStream) is a reasonable upgrade if latency
// needs to drop further.

#include <Arduino.h>
#include <WiFiClient.h>
#include <AudioFileSourceBuffer.h>
#include <AudioFileSourceICYStream.h>
#include <AudioGeneratorMP3.h>
#include <AudioOutputI2S.h>
#include "pins.h"

static AudioGeneratorMP3 *mp3 = nullptr;
static AudioOutputI2S *audioOut = nullptr;

static void ensureAudioOutput() {
  if (audioOut) return;
  audioOut = new AudioOutputI2S();
  audioOut->SetPinout(PIN_I2S_BCLK, PIN_I2S_LRC, PIN_I2S_DIN);
  audioOut->SetGain(0.8);
}

void playMp3Stream(WiFiClient *stream, int contentLength) {
  if (contentLength <= 0) {
    Serial.println("No audio content to play");
    return;
  }

  uint8_t *buf = (uint8_t *)ps_malloc(contentLength);
  if (!buf) {
    Serial.println("Not enough PSRAM to buffer audio response");
    return;
  }

  size_t received = 0;
  unsigned long start = millis();
  while (received < (size_t)contentLength && millis() - start < 5000) {
    if (stream->available()) {
      received += stream->read(buf + received, contentLength - received);
    }
  }

  ensureAudioOutput();

  // Wrap the raw buffer as a file source via a small in-memory reader.
  // AudioFileSourceBuffer expects an underlying AudioFileSource; simplest
  // path here is a minimal wrapper — for a hackathon, writing the buffer to
  // /audio.mp3 on the onboard flash/LittleFS and using AudioFileSourceLittleFS
  // is often more reliable than a custom in-memory source. See TODO below.
  //
  // TODO: replace with AudioFileSourceLittleFS once LittleFS partition is
  // configured, e.g.:
  //   LittleFS.begin();
  //   File f = LittleFS.open("/audio.mp3", "w");
  //   f.write(buf, contentLength);
  //   f.close();
  //   AudioFileSourceLittleFS *file = new AudioFileSourceLittleFS("/audio.mp3");
  //   mp3 = new AudioGeneratorMP3();
  //   mp3->begin(file, audioOut);
  //   while (mp3->isRunning()) mp3->loop();

  Serial.printf("Buffered %d bytes of audio (playback wiring: see TODO in audio_playback.cpp)\n", received);
  free(buf);
}
