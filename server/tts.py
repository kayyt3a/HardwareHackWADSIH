"""Text-to-speech synthesis. Two providers: OpenAI (good quality, needs
network) and a local fallback for offline demo resilience testing."""
import os


def synthesize(text: str) -> bytes:
    provider = os.environ.get("TTS_PROVIDER", "openai")
    if provider == "openai":
        return _synthesize_openai(text)
    return _synthesize_local(text)


def _synthesize_openai(text: str) -> bytes:
    from openai import OpenAI

    client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    response = client.audio.speech.create(
        model="tts-1",
        voice="alloy",
        input=text,
        response_format="mp3",
    )
    return response.content


def _synthesize_local(text: str) -> bytes:
    """Offline fallback using pyttsx3, writes to a temp wav and reads it
    back. Lower quality, but works with zero network dependency — useful for
    demoing the "what happens when the internet drops" story."""
    import tempfile

    import pyttsx3

    engine = pyttsx3.init()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    engine.save_to_file(text, path)
    engine.runAndWait()
    with open(path, "rb") as f:
        data = f.read()
    os.unlink(path)
    return data
