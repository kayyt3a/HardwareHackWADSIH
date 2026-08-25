"""
Single vision-language-model call that reads a label from a photo and
produces a short spoken-friendly summary. Mirrors otto_finder's pattern of
doing OCR + interpretation + response-shaping in one model call rather than
a multi-stage pipeline.
"""
import base64
import json
import os
from typing import Optional

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

_DEFAULT_QUESTION = "What does this say?"


def _call_vision(
    image_bytes: bytes,
    media_type: str,
    question: str,
    user_context: Optional[str] = None,
) -> dict:
    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    prompt_text = (
        f'The person asked: "{question}". Answer that question about '
        "what's in the photo, and respond with the JSON object described in your instructions."
    )
    if user_context:
        prompt_text += f"\n\nFacts about this person, for context only: {user_context}."

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
                        "text": prompt_text,
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


def read_label(
    image_bytes: bytes, media_type: str = "image/jpeg", user_context: Optional[str] = None
) -> dict:
    """Default mode: no spoken question captured (e.g. wake-word triggered
    with no clear question, or the touch-pad backup trigger). Assumes the
    most common ask — "what does this say?" """
    return _call_vision(image_bytes, media_type, _DEFAULT_QUESTION, user_context)


def answer_question(
    image_bytes: bytes,
    question: str,
    media_type: str = "image/jpeg",
    user_context: Optional[str] = None,
) -> dict:
    """A spoken question was captured and transcribed — answer that specific
    question about the photo (colour, currency, comparison, label text,
    whatever the person actually asked)."""
    question = question.strip() or _DEFAULT_QUESTION
    return _call_vision(image_bytes, media_type, question, user_context)
