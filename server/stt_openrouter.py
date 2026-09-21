"""
stt_openrouter.py

Speech-to-text via OpenRouter, which has two different ways to do it:
a dedicated ASR model on /audio/transcriptions, or a multimodal chat model
that accepts audio input on /chat/completions.

Default model: google/gemini-3.5-flash-lite, the same multimodal model
the vision path uses. It takes audio on /chat/completions.

transcribe() tries the transcription endpoint first and falls back to the
chat path if the model turns out to be a chat model, so STT_MODEL can be
set to either kind without touching code.

NOTE: on the normal /ask path this module is NOT used. With FUSE_AUDIO=1
(the default) the photo and the recorded question go to the vision model in
one call and it does the listening. This is the fallback: main.py calls
transcribe() only when that fused call fails, or when FUSE_AUDIO=0.

Model is overridable without touching code:
    STT_MODEL=some/other-model in .env

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

MODEL = os.getenv("STT_MODEL", "google/gemini-3.5-flash-lite")

logger = logging.getLogger("vocalens.stt")


def _human_bytes(n: int) -> str:
    return f"{n / 1_000_000:.1f} MB" if n >= 1_000_000 else f"{n / 1000:.0f} kB"

_TRANSCRIBE_PROMPT = (
    "Transcribe exactly what is said in this audio clip. Reply with ONLY "
    "the transcribed words — no quotes, no commentary, no description of "
    "background noise, nothing else."
)


def transcribe(audio_bytes: bytes, filename: str = "question.wav") -> str:
    """Transcribe spoken audio to text. Matches stt.py's interface (same
    argument names) so main.py can import this module in its place."""
    if not audio_bytes:
        raise OpenRouterError("No audio data to transcribe (0 bytes).")

    # STT_MODEL is a multimodal chat model, so the audio goes to
    # /chat/completions as base64 rather than to /audio/transcriptions.
    # A dedicated ASR model (Whisper, Parakeet, ...) would need the other
    # endpoint and openrouter_client.transcription() instead.
    seconds = pcm.duration_seconds(audio_bytes[44:]) if audio_bytes[:4] == b"RIFF" else 0.0
    logger.info("STT: %s, %s of audio, %.1fs clip",
                MODEL, _human_bytes(len(audio_bytes)), seconds)

    b64_audio = base64.b64encode(audio_bytes).decode("utf-8")

    messages = [
        {
            "role": "user",
            "content": [
                {"type": "text", "text": _TRANSCRIBE_PROMPT},
                {
                    "type": "input_audio",
                    "input_audio": {"data": b64_audio, "format": "wav"},
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
