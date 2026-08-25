"""
Single vision-language-model call that reads a label from a photo and
produces a short spoken-friendly summary. Mirrors otto_finder's pattern of
doing OCR + interpretation + response-shaping in one model call rather than
a multi-stage pipeline.
"""
import base64
import json
import os

from anthropic import Anthropic

_client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

_SYSTEM_PROMPT = """You are the vision component of an assistive device for a
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
by looking themselves."""


def read_label(image_bytes: bytes, media_type: str = "image/jpeg") -> dict:
    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    response = _client.messages.create(
        model="claude-sonnet-5",
        max_tokens=300,
        system=_SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": b64_image,
                        },
                    },
                    {
                        "type": "text",
                        "text": "Read this label and respond with the JSON object described in your instructions.",
                    },
                ],
            }
        ],
    )

    raw_text = response.content[0].text.strip()
    try:
        result = json.loads(raw_text)
    except json.JSONDecodeError:
        result = {
            "spoken_summary": "I couldn't read that clearly, please try again.",
            "category": None,
            "confidence": 0.0,
            "needs_reposition": True,
        }

    result.setdefault("spoken_summary", "I couldn't read that clearly.")
    result.setdefault("category", None)
    result.setdefault("confidence", 0.0)
    result.setdefault("needs_reposition", False)
    return result
