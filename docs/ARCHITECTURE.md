# Architecture

## Data flow

```
[XIAO ESP32S3 Sense, glasses-mounted]
   trigger: wake word (local, on-device) OR temple touch-pad tap
        |
        v
   record ~4s of question audio from onboard mic
   capture JPEG frame
        |
        v  HTTP POST multipart/form-data (image + question_audio)
[FastAPI server, LAN]
        |
        v  Whisper transcription of question_audio (if present)
        v  one Claude vision call: image + transcribed question
   prompt asks for: spoken_summary, category, confidence, needs_reposition
        |
        v  if confidence low or needs_reposition: skip the model's answer,
        |  return a short "can't see that clearly, move closer" message
        v
   TTS synthesis -> MP3 bytes
        |
        v  HTTP response: JSON header + streamed MP3 body
[XIAO ESP32S3 Sense]
   play MP3 over I2S -> amp -> bone-conduction transducer
```

## Why two triggers, not just the wake word

The wake word is the headline UX ("glued to their head," hands-free,
matches how the team wants this to feel to use) but it carries real
technical risk: on-device wake-word spotting (ESP-SR WakeNet) is the hardest
integration in this build, and a demo-night miss with no fallback would
strand the whole demo. The touch pad costs almost nothing to add and means
the rest of the pipeline (camera, mic, server, TTS, playback) can be built
and fully tested well before wake-word detection is working. Build in this
order:
1. Touch pad + camera + `/read_label` (no audio question at all)
2. Touch pad + mic + `/ask` (spoken question, still manually triggered)
3. Wake word replacing/joining the touch pad as the primary trigger

## Why one model call per question, not a pipeline

Same reasoning as otto_finder: doing interpretation + response-shaping in one
Claude vision call (given the transcribed question as context) is simpler to
reason about and cheaper to build in a hackathon timeframe than chaining
multiple models. Speech-to-text is a separate call because Claude's messages
API doesn't take raw audio input directly — Whisper handles that step, then
the transcribed text goes into the same vision call as before. (otto_finder
avoided this by using Gemini via OpenRouter, which accepts audio and image in
a single multimodal call — worth considering as a later optimisation if
reducing to one round-trip matters more than sticking with Anthropic's
vision credits; see `server/vision.py` for the swap point.)

## Latency budget

Trigger → spoken answer, target under ~5-6s (a bit more headroom than a
handheld device since there's a transcription step in the chain now):
- Mic recording: ~2-4s, fixed by how long the person takes to ask
- JPEG capture + WiFi upload: ~200-500ms on local WiFi at VGA resolution
- Whisper transcription: ~0.5-1.5s
- Claude vision call: ~1-3s (dominant network cost — keep the prompt short)
- TTS synthesis + playback start: ~0.5-1s, streamed so playback starts
  before the full file arrives

## Offline behaviour

If the server is unreachable, the firmware falls back to on-device
barcode/QR decode and speaks a locally-stored "no internet, can't look that
up right now" message rather than hanging silently. See
`firmware/src/offline_fallback.h`. Speech-to-text and TTS both need network
in the current config (OpenAI-backed), so the offline path skips the
question entirely rather than attempting a degraded version of it.

## Privacy

- Camera and mic only capture on a trigger (wake word or touch pad). No
  continuous recording or streaming — the local wake-word model only ever
  produces a yes/no keyword match, it does not itself transmit audio.
- Nothing is sent anywhere except the local server on the user's own network.
- State this plainly in the demo pitch — a face-worn camera reads as more
  surveillance-adjacent to an onlooker than a handheld one, so this claim
  needs to be made clearly and be visibly true (e.g. a small LED that lights
  only while actively capturing is worth considering as a trust signal).
