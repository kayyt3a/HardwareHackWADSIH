// Obsolete — safe to delete this file, along with src/audio_sample.h and
// tools/mp3_to_header.py.
//
// This was the MP3-from-flash speaker test, used to prove the audio chain
// before the live path worked. The device no longer decodes MP3 at all:
// the server sends raw 16 kHz mono 16-bit PCM and audio_playback.cpp
// writes it straight to I2S. Emptied rather than deleted because the tool
// that updated the project can't remove files.
//
// For a speaker check that doesn't need WiFi or a server, use:
//   pio run -e beeptest -t upload && pio device monitor -e beeptest
