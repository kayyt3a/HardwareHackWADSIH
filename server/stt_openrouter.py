"""
stt_openrouter.py

Speech-to-text via OpenRouter, which has two different ways to do it:
a dedicated ASR model on /audio/transcriptions, or a multimodal chat model
that accepts audio input on /chat/completions — the same trick
vision_openrouter.py uses to read a label off a photo, applied to audio.
Default model: NVIDIA Parakeet TDT (free), which is the first kind.

transcribe() tries the transcription endpoint first and falls back to the
chat path if the model turns out to be a chat model, so STT_MODEL can be
set to either kind without touching code.

Matches stt.py's transcribe() signature so main.py can import this in its
place:
    import stt_openrouter as stt

Model is overridable without touching code:
    STT_MODEL=some/other-model in .env

Note: this is a general chat model doing transcription as a side task, not
a purpose-built ASR model like Whisper — expect it to be less reliable on
short, noisy, or accented clips. Bench-test it before trusting it in /ask.

Setup (once):
    pip install requests python-dotenv
    Add to the .env file in this folder:
        OPENROUTER_API_KEY=sk-or-...

Bench/CLI usage from a terminal, in this folder:
    python stt_openrouter.py <audio_path>
"""

import base64
import logging
import os
import sys

import pcm
from openrouter_client import OpenRouterError
from openrouter_client import chat_text
from openrouter_client import transcription

MODEL = os.getenv("STT_MODEL", "nvidia/parakeet-tdt-0.6b-v3")

logger = logging.getLogger("vocalens.stt")


def _human_bytes(n: int) -> str:
    return f"{n / 1_000_000:.1f} MB" if n >= 1_000_000 else f"{n / 1000:.0f} kB"

# Formats OpenRouter's audio input documents as supported. If your recorder
# produces something else, convert it first (e.g. with ffmpeg) or add it
# here if it turns out to work anyway.
_SUPPORTED_FORMATS = {"wav", "mp3", "aiff", "aac", "ogg", "flac", "m4a", "pcm16", "pcm24"}

_TRANSCRIBE_PROMPT = (
    "Transcribe exactly what is said in this audio clip. Reply with ONLY "
    "the transcribed words — no quotes, no commentary, no description of "
    "background noise, nothing else."
)


_CONTENT_TYPES = {
    "wav": "audio/wav", "mp3": "audio/mpeg", "ogg": "audio/ogg",
    "flac": "audio/flac", "m4a": "audio/mp4", "aac": "audio/aac",
    "aiff": "audio/aiff",
}


def _content_type(filename: str) -> str:
    ext = os.path.splitext(filename)[1].lstrip(".").lower()
    return _CONTENT_TYPES.get(ext, "audio/wav")


def _is_not_an_asr_model(exc: Exception) -> bool:
    """True when the 400 means "wrong endpoint for this model" rather than
    a real failure — the only case worth retrying the other way."""
    msg = str(exc).lower()
    return "chat/completions" in msg or "not a transcription model" in msg


def _guess_format(filename: str) -> str:
    ext = os.path.splitext(filename)[1].lstrip(".").lower()
    return ext if ext in _SUPPORTED_FORMATS else "wav"


def transcribe(audio_bytes: bytes, filename: str = "question.wav") -> str:
    """Transcribe spoken audio to text. Matches stt.py's interface (same
    argument names) so main.py can import this module in its place."""
    if not audio_bytes:
        raise OpenRouterError("No audio data to transcribe (0 bytes).")

    # Two kinds of model live behind STT_MODEL and they take different
    # endpoints. A dedicated ASR model (Whisper, Parakeet, ...) must go to
    # /audio/transcriptions and 400s on /chat/completions saying exactly
    # that; a multimodal chat model is the reverse. Rather than keeping a
    # list of which is which, try the transcription endpoint first and fall
    # back to the chat path when the model says it isn't one.
    seconds = pcm.duration_seconds(audio_bytes[44:]) if audio_bytes[:4] == b"RIFF" else 0.0
    logger.info("STT: %s, %s of audio, %.1fs clip",
                MODEL, _human_bytes(len(audio_bytes)), seconds)

    try:
        return transcription(MODEL, audio_bytes, filename=filename,
                             content_type=_content_type(filename))
    except OpenRouterError as exc:
        if not _is_not_an_asr_model(exc):
            raise
        # Not an ASR model after all: the whole first call was wasted time,
        # and the chat attempt below pays it again. Worth saying out loud,
        # since it silently doubles this stage's latency on every request.
        logger.warning("STT: %s is not an ASR model — retrying via the chat "
                       "endpoint, which doubles this stage's latency. Set "
                       "STT_MODEL to a dedicated ASR model to avoid it.", MODEL)

    audio_format = _guess_format(filename)
    b64_audio = base64.b64encode(audio_bytes).decode("utf-8")

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": _TRANSCRIBE_PROMPT},
                {
                    "type": "input_audio",
                    "input_audio": {"data": b64_audio, "format": audio_format},
                },
            ],
        }
    ]

    return chat_text(MODEL, messages, temperature=0.0)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python stt_openrouter.py <audio_path>")
        sys.exit(1)

    audio_path = sys.argv[1]
    if not os.path.isfile(audio_path):
        print(f"Error: can't find {audio_path}")
        sys.exit(1)

    with open(audio_path, "rb") as f:
        audio_bytes = f.read()

    try:
        text = transcribe(audio_bytes, filename=audio_path)
    except OpenRouterError as exc:
        print(f"Error: {exc}")
        sys.exit(1)

    print(text)


if __name__ == "__main__":
    main()
