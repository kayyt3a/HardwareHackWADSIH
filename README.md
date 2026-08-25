# Vocalens — FourSight

Hardware Hack 2026 — Challenge 1C, "Eyes for Labels"

A pair of glasses for people with low vision that read the world aloud on
request. Say the wake word and ask a question — "what does this say?",
"what colour is this?", "is this the ten or the twenty?" — and hear a short
spoken answer through a bone-conduction transducer.

Also handles:
- **Barcode/QR scanning** — checked first, before the vision model, so a
  recognised product answers near-instantly with no model call at all.
- **A per-wearer profile** (`server/profile_store.py`, set up once at
  `/setup`) — either dosage-relevant facts (age, weight, conditions,
  allergies) surfaced as context when relevant, or a voice-built reminders
  list ("remember this" / "what do I have coming up"). See
  `docs/ARCHITECTURE.md` for why these are kept as facts-only context, never
  a recommendation.

Built on a Seeed XIAO ESP32S3 Sense as a dumb sensor/actuator (camera, onboard
mic, a temple touch pad as a manual backup trigger, a bone-conduction
transducer for audio out). All intelligence lives server-side in Python,
following the same capture → server → vision-language model → action pattern
as [otto_finder](https://github.com/bethqzak/otto_finder).

## Why glasses, not handheld

Elderly users are prone to losing or forgetting to carry a separate handheld
device. Worn glasses solve that by design — nothing to remember to pick up —
and pointing your face at something is also a more natural aiming motion than
aiming a handheld unit, which directly addresses the brief's repeated point
that "aiming, not reading, is the real problem."

## Activation

Two triggers, by design (see `docs/ARCHITECTURE.md` for the reasoning):
- **Wake word** ("hey ..., what does this say?") — hands-free, the headline
  UX. Runs as local on-device keyword spotting so no audio leaves the glasses
  until it fires.
- **Touch pad on the temple** — manual backup for noisy environments or a
  wake-word miss, and what to build/test against first since the wake-word
  path depends on ESP-SR integration (see `firmware/src/wake_word.h`).

## Why a dedicated device and not just a phone

- Hands-free and always worn — nothing to find, unlock, or hold up.
- Head-aim replaces screen-aim, which matters when you can't see the screen
  to aim it in the first place.
- Silent and camera-off by default: nothing records or transmits until a
  trigger fires — an important claim to be able to make plainly in the pitch
  given a face-worn camera reads as more surveillance-adjacent than a
  handheld one.

## Repo layout

```
firmware/   PlatformIO project for the XIAO ESP32S3 Sense
server/     FastAPI server: speech-to-text + vision call + TTS
docs/       Architecture notes, pitch prep, judging-criteria checklist
```

## Quick start

**Server**
```
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in ANTHROPIC_API_KEY and OPENAI_API_KEY
uvicorn main:app --host 0.0.0.0 --port 8000
```

`pyzbar` (barcode decoding) needs the system `zbar` library — `apt install
libzbar0` on Debian/Ubuntu, `brew install zbar` on macOS — install that
before `pip install -r requirements.txt` if the import fails.

Visit `http://<server-ip>:8000/setup` to set up a wearer's profile
(dosage facts or reminders mode) before a demo.

**Firmware**
```
cd firmware
cp src/secrets.h.example src/secrets.h   # fill in WiFi + server IP
pio run -t upload
```

Bring-up order: get the touch-pad trigger + camera + `/read_label` round trip
working first (no mic, no wake word needed), then layer on mic recording +
`/ask`, then wake-word detection last — it's the highest-risk piece, see
`firmware/src/wake_word.h`.

See `docs/ARCHITECTURE.md` for the full data flow and `docs/JUDGING_CHECKLIST.md`
for how this addresses the brief's dignity/privacy/failure-mode questions.
