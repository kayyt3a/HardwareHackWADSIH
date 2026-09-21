"""
tts_openrouter.py

Text-to-speech for VocaLens. Turns the spoken answer from /ask into audio
the glasses can play.

Model: x-ai/grok-voice-tts-1.0 (Grok), voice "ara", via OpenRouter's
/audio/speech endpoint.

What it does:
    synthesize(text) asks the model for audio and returns RAW PCM: 16 kHz,
    16-bit, mono. The board's I2S amp plays those bytes directly, so the
    firmware needs no decoder. pcm.py does the resampling / conversion.

Important notes:
    - Grok only accepts response_format "pcm" or "mp3". "pcm" is used; MP3
      is not an option because there is no MP3 decoder on this path.
    - FORMAT_CANDIDATES are tried in order and the first accepted one is
      remembered. Set TTS_FORMAT=pcm to skip the check.
    - For "pcm", the source rate is read from the response's Content-Type.
      TTS_SOURCE_RATE is only the fallback. If it's wrong nothing errors;
      the voice just plays at the wrong speed and pitch.
    - TTS_SPEED (default 1.2) is asked of the provider first. If refused,
      the audio is sped up locally instead, which also raises the pitch.

Settings (.env or Railway variables, all optional):
    TTS_MODEL, TTS_VOICE, TTS_FORMAT, TTS_SPEED, TTS_SOURCE_RATE,
    TTS_OUTPUT_DIR

Test from a terminal in this folder:
    python tts_openrouter.py "some text to speak" [output.wav]
Saves a playable WAV to audio_output/.
"""
import logging
import os
import re
import sys
from datetime import datetime
from typing import Optional

import pcm
from openrouter_client import OpenRouterError
from openrouter_client import speech

OUTPUT_DIR = os.getenv(
    "TTS_OUTPUT_DIR",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio_output"),
)

MODEL = os.getenv("TTS_MODEL", "x-ai/grok-voice-tts-1.0")
VOICE = os.getenv("TTS_VOICE", "ara")

SAMPLE_RATE = pcm.TARGET_RATE

# How fast the reply is spoken. 1.0 is the voice's own pace; 1.2 is a fifth
# quicker. Set TTS_SPEED in .env to taste.
#
# Asked of the provider first, as OpenAI-compatible /audio/speech takes a
# "speed" parameter — done there the model simply reads faster and keeps its
# own pitch. Support varies, so a model that rejects it falls back to
# resampling the audio here, which speeds it up and raises the pitch with it.
SPEED = float(os.getenv("TTS_SPEED", "1.2"))
SPEED_MIN, SPEED_MAX = 0.5, 2.0

# None = not yet known, True/False = settled after the first attempt, so only
# that call pays for finding out. Same idea as _working_format below.
_provider_speed = None

logger = logging.getLogger("vocalens.tts")

# Tried in order until one isn't rejected. "pcm" is bare samples — exactly
# what the glasses want, no conversion at all — and "wav" is the fallback
# for models that only do containers.
FORMAT_CANDIDATES = ["pcm", "wav"]

# Fallback source rate for "pcm" when the response doesn't state one.
SOURCE_RATE = int(os.getenv("TTS_SOURCE_RATE", "24000"))

# Set from .env if given, otherwise discovered on the first call and then
# reused, so only that call pays for the probing.
_working_format = os.getenv("TTS_FORMAT")


def _rate_from_content_type(content_type: str) -> Optional[int]:
    match = re.search(r"rate=(\d+)", content_type or "")
    return int(match.group(1)) if match else None


def _request(text: str, fmt: str) -> tuple:
    """One attempt at one format. Returns (audio_bytes, source_rate, sped_up).
    rate/channels are only meaningful for "pcm"; harmless extras elsewhere.

    `sped_up` says whether the provider applied SPEED itself. When it didn't,
    the caller resamples instead."""
    global _provider_speed

    extra = {}
    if fmt == "pcm":
        extra = {"rate": SAMPLE_RATE, "channels": pcm.TARGET_CHANNELS}

    want_speed = abs(SPEED - 1.0) >= 0.01
    ask_provider = want_speed and _provider_speed is not False
    if ask_provider:
        extra["speed"] = SPEED

    try:
        audio, content_type = speech(MODEL, text, VOICE, response_format=fmt, **extra)
    except OpenRouterError as exc:
        # Only a rejection OF THE SPEED PARAMETER is worth retrying without
        # it. A 400 about the format is the caller's business.
        if not ask_provider or "400" not in str(exc):
            raise
        logger.info("%s won't take speed=%.2f — resampling locally instead",
                    MODEL, SPEED)
        _provider_speed = False
        extra.pop("speed")
        audio, content_type = speech(MODEL, text, VOICE, response_format=fmt, **extra)
    else:
        if ask_provider:
            _provider_speed = True

    # Trust what came back over what was asked for: providers are free to
    # ignore the requested rate, and a WAV carries its own rate anyway.
    rate = _rate_from_content_type(content_type) or SOURCE_RATE
    return audio, rate, bool(ask_provider and _provider_speed)


def synthesize(text: str) -> bytes:
    """Text -> raw 16 kHz mono 16-bit PCM bytes."""
    global _working_format

    if not text or not text.strip():
        raise OpenRouterError("No text given to synthesize.")

    candidates = [_working_format] if _working_format else list(FORMAT_CANDIDATES)

    last_error = None
    for fmt in candidates:
        try:
            audio, source_rate, sped_up = _request(text, fmt)
        except OpenRouterError as exc:
            # A 400 here means this model doesn't do this format. Anything
            # else (auth, rate limit, network) is not worth retrying under a
            # different format, so let it out.
            if "400" not in str(exc):
                raise
            last_error = exc
            continue

        try:
            converted = pcm.to_pcm(audio, source_rate, pcm.TARGET_CHANNELS)
        except pcm.PcmError as exc:
            raise OpenRouterError(str(exc)) from exc

        if not sped_up and abs(SPEED - 1.0) >= 0.01:
            if not SPEED_MIN <= SPEED <= SPEED_MAX:
                raise OpenRouterError(
                    f"TTS_SPEED {SPEED} outside {SPEED_MIN}-{SPEED_MAX}")
            converted = pcm.speed_up(converted, SPEED)

        _working_format = fmt
        logger.info("TTS: %s / %s, format=%s, source %d Hz -> %d Hz, speed %.2f (%s)",
                    MODEL, VOICE, fmt, source_rate, SAMPLE_RATE, SPEED,
                    "provider" if sped_up else "resampled")
        return converted

    raise OpenRouterError(
        f"{MODEL} rejected every audio format tried ({', '.join(candidates)}). "
        f"Last response: {last_error} — check the model's OpenRouter page for "
        "what response_format it supports and set TTS_FORMAT in .env."
    )


def main() -> None:
    if len(sys.argv) < 2:
        print('Usage: python tts_openrouter.py "text to speak" [output.wav]')
        sys.exit(1)

    text = sys.argv[1]
    filename = sys.argv[2] if len(sys.argv) > 2 else None

    if filename is None:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = os.path.join(OUTPUT_DIR, f"tts_{stamp}.wav")
    elif os.path.isabs(filename) or os.path.dirname(filename):
        output_path = filename
    else:
        output_path = os.path.join(OUTPUT_DIR, filename)

    parent = os.path.dirname(output_path)
    if parent:
        os.makedirs(parent, exist_ok=True)

    try:
        pcm_bytes = synthesize(text)
    except OpenRouterError as exc:
        print(f"Error: {exc}")
        sys.exit(1)

    with open(output_path, "wb") as f:
        f.write(pcm.pcm_to_wav(pcm_bytes, SAMPLE_RATE))

    print(f"Saved {pcm.duration_seconds(pcm_bytes):.1f}s "
          f"({len(pcm_bytes)} bytes of PCM) to {output_path}")


if __name__ == "__main__":
    main()
