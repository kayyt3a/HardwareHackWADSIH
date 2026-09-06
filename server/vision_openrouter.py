"""
vision_openrouter.py

Reads a label / product photo and produces a short, spoken-friendly summary
for a low-vision assistive device, using a vision-capable model on
OpenRouter (default: the free MiniMax M3).

Same interface as vision.py (read_label / answer_question, taking image
BYTES + a media type), so main.py can import this in its place:
    import vision_openrouter as vision

Model is overridable without touching code:
    VISION_MODEL=some/other-model in .env

Setup (once):
    pip install requests python-dotenv
    Add to the .env file in this folder:
        OPENROUTER_API_KEY=sk-or-...

Bench/CLI usage from a terminal, in this folder:
    python vision_openrouter.py <image_path>
    python vision_openrouter.py <image_path> "what colour is this?"
"""

import base64
import json
import mimetypes
import os
import re
import sys
from typing import Optional

from openrouter_client import OpenRouterError as VisionError
from openrouter_client import chat_text

MODEL = os.getenv("VISION_MODEL", "google/gemma-4-31b-it")
DEFAULT_QUESTION = "What does this say?"
MAX_IMAGE_BYTES = 4_000_000   # downscale images bigger than ~4 MB

SYSTEM_PROMPT = """You are the vision component of an assistive device for a
person with low vision. They have just pointed a camera at a label, product,
or piece of printed text and pressed a button to have it read aloud.

Respond with ONLY a JSON object, no other text, with these fields:
- "spoken_summary": a single short sentence (under 20 words) suitable for
  text-to-speech, giving the single most useful piece of information on the
  label. Not a transcription of every word — the one thing this person needs
  to know right now (e.g. "This is ibuprofen 200mg, use by March 2027" not a
  full reading of the packet).
- "category": a short 1-3 word category if identifiable (e.g. "medication",
  "shampoo", "canned food"), or null if not identifiable.
- "confidence": a float 0.0-1.0 for how confident you are in this reading.
- "needs_reposition": true if the image is too blurry, too dark, cropped, or
  at an angle that prevents a confident read.

Be honest about uncertainty. It is much better to say "I can't read this
clearly" than to guess and be wrong — this person cannot verify your answer
by looking themselves.

Do not make medical, dosage, or clinical claims even if the label is a
medication — describe what is printed, nothing more.

You may be given facts about the person (age, weight, known conditions,
known allergies) as context. If given, you may mention when something
printed on the label is directly relevant to one of those facts (e.g. an
allergen they've listed appears in the ingredients) — but only to point out
that a printed detail exists, never to judge whether it's safe for them.
Phrase it as "this contains X, which you've noted as an allergy" not "this
is unsafe for you" or "you should/shouldn't take this". If no such facts are
given, don't mention a profile at all."""


def _downscale_image(image_bytes: bytes) -> tuple[bytes, str]:
    """Shrink a large photo using Pillow, if installed. Falls back to the
    original bytes untouched if that's not possible."""
    try:
        from io import BytesIO

        from PIL import Image

        img = Image.open(BytesIO(image_bytes))
        img = img.convert("RGB")
        img.thumbnail((1600, 1600))
        buf = BytesIO()
        img.save(buf, format="JPEG", quality=85)
        return buf.getvalue(), "image/jpeg"
    except Exception:
        return image_bytes, "image/jpeg"


def _extract_json(raw_text: str) -> dict:
    """The model is asked to return only JSON, but vision models sometimes
    wrap it in ```json fences or add a stray sentence. Try a few ways to
    pull the JSON object out before giving up."""
    text = raw_text.strip()

    fence_match = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.DOTALL)
    if fence_match:
        text = fence_match.group(1)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    brace_match = re.search(r"\{.*\}", text, re.DOTALL)
    if brace_match:
        try:
            return json.loads(brace_match.group(0))
        except json.JSONDecodeError:
            pass

    raise VisionError(
        "The model didn't return valid JSON. Raw reply was:\n" + raw_text[:500]
    )


def _call_vision(image_bytes: bytes, media_type: str, question: str, user_context: Optional[str] = None) -> dict:
    if len(image_bytes) > MAX_IMAGE_BYTES:
        image_bytes, media_type = _downscale_image(image_bytes)

    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    prompt_text = (
        f'The person asked: "{question}". Answer that question about '
        "what's in the photo, and respond with the JSON object described in your instructions."
    )
    if user_context:
        prompt_text += f"\n\nFacts about this person, for context only: {user_context}."

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": [
                {"type": "text", "text": prompt_text},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:{media_type};base64,{b64_image}"},
                },
            ],
        },
    ]

    raw_text = chat_text(MODEL, messages, temperature=0.2)
    result = _extract_json(raw_text)

    result.setdefault("spoken_summary", "I couldn't read that clearly.")
    result.setdefault("category", None)
    result.setdefault("confidence", 0.0)
    result.setdefault("needs_reposition", False)
    return result


def read_label(image_bytes: bytes, media_type: str = "image/jpeg", user_context: Optional[str] = None) -> dict:
    """Default mode: no spoken question captured. Assumes the most common
    ask — "what does this say?" Matches vision.py's signature so main.py
    can import this module in its place."""
    return _call_vision(image_bytes, media_type, DEFAULT_QUESTION, user_context)


def answer_question(
    image_bytes: bytes,
    question: str,
    media_type: str = "image/jpeg",
    user_context: Optional[str] = None,
) -> dict:
    """A spoken question was captured — answer that specific question about
    the photo. Matches vision.py's signature."""
    question = question.strip() or DEFAULT_QUESTION
    return _call_vision(image_bytes, media_type, question, user_context)


def _read_image_file(image_path: str) -> tuple[bytes, str]:
    """CLI-only helper: load an image off disk and guess its media type."""
    if not os.path.isfile(image_path):
        raise VisionError(f"Can't find the image file: {image_path}")

    media_type, _ = mimetypes.guess_type(image_path)
    if not media_type or not media_type.startswith("image/"):
        media_type = "image/jpeg"

    with open(image_path, "rb") as f:
        image_bytes = f.read()

    if not image_bytes:
        raise VisionError(f"{image_path} is empty (0 bytes).")

    return image_bytes, media_type


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python vision_openrouter.py <image_path> [question]")
        sys.exit(1)

    image_path = sys.argv[1]
    question = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        image_bytes, media_type = _read_image_file(image_path)
        if question:
            result = answer_question(image_bytes, question, media_type)
        else:
            result = read_label(image_bytes, media_type)
    except VisionError as exc:
        print(f"Error: {exc}")
        sys.exit(1)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
