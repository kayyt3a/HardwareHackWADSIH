# PocketLabel

Hardware Hack 2026 — Challenge 1C, "Eyes for Labels"

A handheld, point-and-hear label reader for people with low vision. Point it at a
label, feel a haptic buzz that speeds up as you aim correctly, press the button,
and hear a short spoken summary of what the label says.

Built on a Seeed XIAO ESP32S3 Sense as a dumb sensor/actuator (camera, mic, one
button, a distance sensor, a vibration motor, a small I2S speaker). All intelligence
lives server-side in Python, following the same capture → server → vision-language
model → action pattern as [otto_finder](https://github.com/bethqzak/otto_finder).

## Why a dedicated device and not just a phone

- Always ready: no unlock, no app switch, no menu.
- One-handed and physically aimable — the haptic buzz tells you when you're
  on-target *before* you commit to a read, which a flat phone screen can't do
  for someone who can't see the screen.
- Silent by default: nothing records or transmits until the button is pressed.

## Repo layout

```
firmware/   PlatformIO project for the XIAO ESP32S3 Sense
server/     FastAPI server: vision call + TTS
docs/       Architecture notes, pitch prep, judging-criteria checklist
```

## Quick start

**Server**
```
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in ANTHROPIC_API_KEY (and OPENAI_API_KEY if using OpenAI TTS)
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Firmware**
```
cd firmware
# edit src/secrets.h with your WiFi SSID/password and the server's LAN IP
pio run -t upload
```

See `docs/ARCHITECTURE.md` for the full data flow and `docs/JUDGING_CHECKLIST.md`
for how this addresses the brief's dignity/privacy/failure-mode questions.
