"""
Cheap keyword-based intent classification for the transcribed question, so
"remember this" and "what do I have coming up" don't need a model call to
route correctly. Deliberately not an LLM call — this needs to be instant and
the vocabulary is small and predictable.

Good enough for a hackathon demo; a small on-device or lite-model classifier
is the natural upgrade if the phrase set grows past what keyword matching
can reliably catch.
"""

_REMEMBER_PHRASES = ["remember this", "remember that", "save this", "add this"]
_RECALL_PHRASES = [
    "what do i have", "what's coming up", "whats coming up",
    "what did i save", "what have i saved", "read my reminders",
    "what's on my list", "whats on my list",
]


def classify(question: str) -> str:
    """Returns "remember", "recall", or "ask" (the default: answer a
    question about what's in front of the camera)."""
    q = (question or "").lower().strip()
    if any(phrase in q for phrase in _REMEMBER_PHRASES):
        return "remember"
    if any(phrase in q for phrase in _RECALL_PHRASES):
        return "recall"
    return "ask"
