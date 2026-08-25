"""Speech-to-text for the spoken question captured on-device ("what does
this say?", "what colour is this?", ...). Uses OpenAI Whisper — same
OPENAI_API_KEY already needed for TTS."""
import io
import os


def transcribe(audio_bytes: bytes, filename: str = "question.wav") -> str:
    from openai import OpenAI

    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename  # SDK reads this to infer format
    result = client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
    )
    return result.text.strip()
