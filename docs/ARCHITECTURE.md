# Architecture

## Data flow

```
[XIAO ESP32S3 Sense]
   button press
        |
        v
   read distance sensor (ToF/ultrasonic) --> drive vibration motor
   (continuous, no network — this loop runs even before capture,
   so the user feels aim quality in real time)
        |
   on button press: capture JPEG frame
        |
        v  HTTP POST multipart/form-data (image + distance_mm)
[FastAPI server, LAN]
        |
        v  one Claude vision call (see server/vision.py)
   prompt asks for: spoken_summary, category, confidence, needs_reposition
        |
        v  if confidence low or needs_reposition: skip TTS of label content,
        |  return a short "move closer" / "I can't read this clearly" message
        v
   TTS synthesis (server/tts.py) -> MP3 bytes
        |
        v  HTTP response: JSON header + streamed MP3 body
[XIAO ESP32S3 Sense]
   play MP3 over I2S to MAX98357A amp + small speaker
```

## Why one model call, not a pipeline of models

Same reasoning as otto_finder: OCR + classification + summarisation in one
Claude vision call is simpler to reason about, cheaper to build in a hackathon
timeframe, and avoids compounding errors across stages. If we want to show
OpenRouter multi-model routing for the showcase track, add a cheap/fast model
(e.g. Gemini Flash Lite) for the continuous "is a label even present in frame"
pre-check, and keep Claude for the actual read — see `server/vision.py` for the
hook point (`quick_precheck_enabled` flag).

## Latency budget

Target: point → buzz feedback is instant (local, no network). Button press ->
spoken answer should land under ~4s so it's usable standing in a supermarket
aisle. Break down:
- JPEG capture + WiFi upload: ~200-500ms on local WiFi at QVGA/VGA resolution
- Claude vision call: ~1-3s (dominant cost — keep the prompt short, ask for
  terse JSON only)
- TTS synthesis: ~0.5-1s depending on provider
- MP3 playback start: near-instant once first bytes arrive (stream, don't wait
  for the whole file)

## Offline behaviour

If the server is unreachable (WiFi connect fails, or POST times out after
~3s), the firmware falls back to on-device barcode/QR decode (fast, no network
needed) and speaks a locally-stored "barcode found, no internet — can't look it
up right now" message rather than hanging silently. See
`firmware/src/offline_fallback.h`.

## Privacy

- Camera only captures on button press. No continuous streaming, no local or
  server-side storage of images beyond the lifetime of a single request.
- Nothing is sent anywhere except the local server on the user's own network.
- State this plainly in the demo pitch, per the brief's requirement.
