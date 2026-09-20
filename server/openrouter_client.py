"""
openrouter_client.py

Shared, minimal client for calling ANY OpenRouter model off a single
OPENROUTER_API_KEY — chat/vision/audio-input via /chat/completions, and
speech synthesis via /audio/speech, and transcription via
/audio/transcriptions.

vision_openrouter.py, stt_openrouter.py and tts_openrouter.py all import
this instead of talking to `requests` directly, so the request building,
retries, and error messages live in exactly one place. Each of those files
just picks a model name (overridable via its own env var — VISION_MODEL,
STT_MODEL, TTS_MODEL) and shapes its own prompt/messages.

Requires:
    pip install requests python-dotenv
    OPENROUTER_API_KEY=sk-or-... in a .env file in this folder
"""
import logging
import os
import time
from typing import Optional

import requests
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("vocalens.openrouter")

BASE_URL = "https://openrouter.ai/api/v1"
API_KEY = os.getenv("OPENROUTER_API_KEY")

REQUEST_TIMEOUT = 60          # seconds to wait for a response
MAX_RETRIES = 2               # retries for transient network errors only
RETRY_BACKOFF_SECONDS = 3     # wait between retries


class OpenRouterError(Exception):
    """Any failure calling OpenRouter, with a message meant to be shown
    directly to a user rather than a raw Python traceback."""


def _check_api_key() -> None:
    if not API_KEY:
        raise OpenRouterError(
            "No OPENROUTER_API_KEY found. Add to the .env file in this folder:\n"
            "    OPENROUTER_API_KEY=sk-or-your-key-here"
        )


def _headers(extra: Optional[dict] = None) -> dict:
    headers = {"Authorization": f"Bearer {API_KEY}"}
    if extra:
        headers.update(extra)
    return headers


def _request_with_retries(method: str, url: str, **kwargs) -> requests.Response:
    _check_api_key()

    last_error = None
    endpoint = url.rsplit("/", 1)[-1]
    for attempt in range(1, MAX_RETRIES + 2):  # first try + retries
        began = time.perf_counter()
        try:
            response = requests.request(method, url, timeout=REQUEST_TIMEOUT, **kwargs)
        except requests.exceptions.Timeout:
            last_error = OpenRouterError(
                "Timed out waiting for OpenRouter to respond. Free models can "
                "be slow or overloaded — try again in a moment."
            )
        except requests.exceptions.ConnectionError as exc:
            last_error = OpenRouterError(
                "Couldn't connect to OpenRouter. Check your internet connection "
                f"(or a proxy/firewall blocking it). Details: {exc}"
            )
        else:
            if response.status_code == 401:
                raise OpenRouterError(
                    "OpenRouter rejected the API key (401). Check "
                    "OPENROUTER_API_KEY in your .env file."
                )
            if response.status_code == 429:
                raise OpenRouterError(
                    "Rate limited by OpenRouter (429). Free models are capped "
                    "at 50 requests/day (1000/day once the account has $10+ "
                    "purchased credit). Wait and try again."
                )
            if response.status_code >= 500:
                last_error = OpenRouterError(
                    f"OpenRouter server error ({response.status_code}). Retrying..."
                )
            elif response.status_code >= 400:
                # Surface WHAT the API objected to. Without this a 400 is an
                # opaque "Bad Request" and the usual cause — an unsupported
                # response_format or voice for this model — stays invisible.
                detail = ""
                try:
                    body = response.json()
                    detail = body.get("error", {}).get("message") or str(body)
                except Exception:
                    detail = response.text[:500]
                raise OpenRouterError(
                    f"OpenRouter rejected the request ({response.status_code}): {detail}"
                )
            else:
                response.raise_for_status()
                # Where the time in one OpenRouter call actually went.
                # `elapsed` is request-sent -> response headers, which for a
                # non-streamed reply is essentially the whole server-side
                # wait (connect + TLS + upload + queue + inference). The
                # remainder is pulling the body down to us.
                total = time.perf_counter() - began
                to_headers = response.elapsed.total_seconds()
                sent = _payload_size(kwargs)
                logger.info(
                    "%s attempt %d: %.2fs total (%.2fs to headers, %.2fs body), "
                    "sent %s, got %s",
                    endpoint, attempt, total, to_headers, total - to_headers,
                    _human_bytes(sent), _human_bytes(len(response.content)),
                )
                return response

        if attempt <= MAX_RETRIES:
            time.sleep(RETRY_BACKOFF_SECONDS)

    raise last_error


def _payload_size(kwargs: dict) -> int:
    """Roughly how many bytes we uploaded, for the latency log. Base64 in a
    JSON body and multipart file uploads are counted differently, hence
    both branches."""
    if "json" in kwargs:
        try:
            import json as _json
            return len(_json.dumps(kwargs["json"]))
        except Exception:
            return 0
    total = 0
    for value in (kwargs.get("files") or {}).values():
        if isinstance(value, (tuple, list)) and len(value) > 1 and isinstance(value[1], bytes):
            total += len(value[1])
    return total


def _human_bytes(n: int) -> str:
    return f"{n / 1_000_000:.1f} MB" if n >= 1_000_000 else f"{n / 1000:.0f} kB"


def chat_completion(model: str, messages: list, **extra_payload) -> dict:
    """POST /chat/completions with any model + messages. Returns the parsed
    JSON body. Use this directly if you need the full response (usage,
    finish_reason, etc); use chat_text() below if you just want the reply."""
    payload = {"model": model, "messages": messages, **extra_payload}
    response = _request_with_retries(
        "POST",
        f"{BASE_URL}/chat/completions",
        headers=_headers({"Content-Type": "application/json"}),
        json=payload,
    )
    data = response.json()
    if "error" in data:
        raise OpenRouterError(f"OpenRouter returned an error: {data['error']}")
    return data


def chat_text(model: str, messages: list, **extra_payload) -> str:
    """Convenience wrapper around chat_completion(): returns just the
    model's reply text, stripped. Used by both vision (image_url content)
    and STT (input_audio content) — the messages shape is the caller's job,
    this just handles the request/response plumbing."""
    data = chat_completion(model, messages, **extra_payload)

    choices = data.get("choices") or []
    if not choices:
        raise OpenRouterError(f"No response choices came back. Full reply: {data}")

    text = choices[0]["message"]["content"]
    if not text or not text.strip():
        raise OpenRouterError("The model returned an empty reply — try again.")

    return text.strip()


def speech(model: str, text: str, voice: str, response_format: str = "mp3",
           **extra_payload) -> tuple:
    """POST /audio/speech. Returns (audio_bytes, content_type).

    Format support varies by model, so an unsupported response_format is a
    400 — see FORMAT_CANDIDATES in tts_openrouter.py. "pcm" returns bare
    samples and takes optional "rate" and "channels" via extra_payload.

    The Content-Type comes back too because raw PCM has no header describing
    itself, and its rate (e.g. "audio/pcm; rate=24000") is the only way to
    know how to resample. Guessing wrong doesn't fail loudly — it plays at
    the wrong speed and pitch, which sounds like a different voice.""" 
    payload = {
        "model": model,
        "input": text,
        "voice": voice,
        "response_format": response_format,
    }
    payload.update(extra_payload)
    response = _request_with_retries(
        "POST",
        f"{BASE_URL}/audio/speech",
        headers=_headers({"Content-Type": "application/json"}),
        json=payload,
    )
    return response.content, response.headers.get("Content-Type", "")


def transcription(model: str, audio_bytes: bytes, filename: str = "audio.wav",
                  content_type: str = "audio/wav", **extra_payload) -> str:
    """POST /audio/transcriptions. Returns the transcribed text.

    This is the endpoint dedicated ASR models (Whisper, Parakeet, ...) use.
    They are NOT chat models: sending them to /chat/completions is a 400
    saying so in as many words. Multimodal chat models that happen to accept
    audio are the opposite case and go through chat_text() instead — see
    stt_openrouter.transcribe(), which tries this first and falls back.

    The audio goes as a multipart file upload rather than base64 JSON, so
    Content-Type is left to requests, which has to set the boundary."""
    payload = {"model": model}
    payload.update(extra_payload)

    response = _request_with_retries(
        "POST",
        f"{BASE_URL}/audio/transcriptions",
        headers=_headers(),
        files={"file": (filename, audio_bytes, content_type)},
        data=payload,
    )

    try:
        data = response.json()
    except ValueError:
        # Some providers answer text/plain when response_format isn't json.
        text = response.text.strip()
        if text:
            return text
        raise OpenRouterError("Transcription returned an unreadable response.")

    if "error" in data:
        raise OpenRouterError(f"OpenRouter returned an error: {data['error']}")

    text = (data.get("text") or "").strip()
    if not text:
        raise OpenRouterError(
            "Transcription came back empty — the clip may be silence. Play "
            "the saved WAV in server/questions/ to check."
        )
    return text
