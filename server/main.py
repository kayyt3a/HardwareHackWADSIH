"""
PocketLabel server — glasses form factor.

/ask receives a JPEG frame and an optional recorded question (audio) from
the XIAO ESP32S3 Sense. Flow:
  1. transcribe the question, if audio was captured
  2. classify intent: "remember" (save this to the profile), "recall" (read
     back saved reminders, no camera needed), or "ask" (the default —
     answer a question about what's in the photo)
  3. for "ask": try a barcode/QR decode + Open Food Facts lookup first
     (near-instant, no model call) before falling back to the vision model
  4. synthesize a short spoken response and stream it back

/read_label is kept as a simple no-audio path for bench-testing the vision
call without wiring up the mic first.

Run: uvicorn main:app --host 0.0.0.0 --port 8000
"""
import io
import logging
import os
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles

load_dotenv()

import barcode
import intent
import profile_store
import stt
import tts
import vision

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("pocketlabel")

app = FastAPI(title="PocketLabel server")
app.mount("/setup", StaticFiles(directory="static", html=True), name="setup")

CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.55"))
DEFAULT_USER_ID = "default"  # single-wearer device for the hackathon demo


def _speak(spoken: str, confidence: float = 1.0, category: Optional[str] = None) -> StreamingResponse:
    audio_bytes = tts.synthesize(spoken)
    return StreamingResponse(
        io.BytesIO(audio_bytes),
        media_type="audio/mpeg",
        headers={
            "X-Spoken-Text": spoken,
            "X-Confidence": str(confidence),
            "X-Category": str(category),
        },
    )


def _speak_vision_result(result: dict) -> StreamingResponse:
    if result["needs_reposition"] or result["confidence"] < CONFIDENCE_THRESHOLD:
        spoken = "I can't see that clearly. Try turning your head a little, or moving closer."
    else:
        spoken = result["spoken_summary"]
    return _speak(spoken, result["confidence"], result["category"])


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ask")
async def ask(
    image: UploadFile = File(...),
    question_audio: Optional[UploadFile] = File(None),
    user_id: str = Form(DEFAULT_USER_ID),
):
    image_bytes = await image.read()
    logger.info("Received frame: %d bytes", len(image_bytes))

    question = None
    if question_audio is not None:
        audio_bytes = await question_audio.read()
        if audio_bytes:
            try:
                question = stt.transcribe(audio_bytes, filename=question_audio.filename or "q.wav")
                logger.info("Transcribed question: %r", question)
            except Exception:
                logger.exception("Transcription failed, falling back to default question")

    detected_intent = intent.classify(question) if question else "ask"
    logger.info("Intent: %s", detected_intent)

    if detected_intent == "recall":
        reminders = profile_store.list_reminders(user_id)
        if not reminders:
            return _speak("You don't have anything saved yet.")
        spoken_list = "; ".join(r["text"] for r in reminders[-5:])
        return _speak(f"Here's what you've got: {spoken_list}.")

    if detected_intent == "remember":
        result = vision.read_label(image_bytes, media_type=image.content_type or "image/jpeg")
        profile_store.add_reminder(user_id, result["spoken_summary"])
        return _speak(f"Got it, I've saved: {result['spoken_summary']}")

    # detected_intent == "ask" — try the fast barcode path first
    code = barcode.decode(image_bytes)
    if code:
        product = barcode.lookup_product(code)
        if product and product.get("name"):
            spoken = product["name"]
            if product.get("brand"):
                spoken = f"{product['brand']} {spoken}"
            if product.get("expiry_date"):
                spoken += f", use by {product['expiry_date']}"
            logger.info("Answered from barcode lookup, no model call")
            return _speak(spoken, confidence=1.0, category="barcode")
        # barcode decoded but not found in the product database — fall
        # through to the vision model rather than dead-ending

    user_context = profile_store.dosage_context_summary(user_id)
    if question:
        result = vision.answer_question(
            image_bytes, question, media_type=image.content_type or "image/jpeg", user_context=user_context
        )
    else:
        result = vision.read_label(
            image_bytes, media_type=image.content_type or "image/jpeg", user_context=user_context
        )

    logger.info("Vision result: %s", result)
    return _speak_vision_result(result)


@app.post("/read_label")
async def read_label(image: UploadFile = File(...)):
    """No-audio path, for bench-testing before the mic is wired up."""
    image_bytes = await image.read()
    result = vision.read_label(image_bytes, media_type=image.content_type or "image/jpeg")
    logger.info("Vision result: %s", result)
    return _speak_vision_result(result)


@app.get("/profile/{user_id}")
def get_profile(user_id: str):
    return profile_store.get_profile(user_id)


@app.post("/profile/{user_id}")
def set_profile(
    user_id: str,
    profile_type: Optional[str] = Form(None),  # "dosage" or "reminders"
    age: Optional[int] = Form(None),
    weight_kg: Optional[float] = Form(None),
    conditions: Optional[str] = Form(None),  # comma-separated
    allergies: Optional[str] = Form(None),  # comma-separated
):
    return profile_store.set_profile_fields(
        user_id,
        profile_type=profile_type,
        age=age,
        weight_kg=weight_kg,
        conditions=[c.strip() for c in conditions.split(",")] if conditions else None,
        allergies=[a.strip() for a in allergies.split(",")] if allergies else None,
    )
