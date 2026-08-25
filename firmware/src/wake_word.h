// Wake-word detection integration point.
//
// Recommended approach: Espressif's ESP-SR component (WakeNet for wake-word
// spotting + MultiNet for a small on-device command set), which is built to
// run locally on the ESP32-S3 — meaning no audio leaves the glasses until
// the wake word actually fires. This matters for the pitch: "always
// listening" only means a local keyword match is running, nothing is
// streamed or stored until triggered.
//
// Two real constraints to resolve early with mentors, not on demo night:
//  1. ESP-SR ships pretrained wake words (e.g. "Hi ESP"). A fully custom
//     wake word ("Hey <name>") typically needs Espressif's model-training
//     service/partner flow — confirm turnaround time before committing to
//     a custom phrase in the pitch. If it doesn't land in time, ship the
//     stock wake word and describe the custom phrase as a next step.
//  2. ESP-SR is an ESP-IDF component; wiring it into a PlatformIO Arduino
//     project needs the espressif32 platform's IDF component support (or
//     dropping to pure ESP-IDF for this module). Budget real time for this
//     integration specifically — it's the highest-risk item in the build.
//
// Until that's wired up, isWakeWordDetected() is a stub that always returns
// false, so the touch pad (see PIN_TOUCH_PAD in pins.h) is what actually
// triggers capture during early bring-up and stays as the demo-night backup.
#pragma once

inline void setupWakeWord() {
  // TODO: init ESP-SR WakeNet here
}

inline bool isWakeWordDetected() {
  // TODO: poll WakeNet detection result
  return false;
}
