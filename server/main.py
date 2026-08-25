"""
PocketLabel server — glasses form factor.

/ask receives a JPEG frame and an optional recorded question (audio) from
the XIAO ESP32S3 Sense, transcribes the question if present, runs one Claude
vision call to answer it about the photo, synthesizes a short spoken
response, and streams the audio back.

/read_label is kept as a simple no-audio path for bench-testing the vision
call without wiring up the mic first.

Run: uvicorn main:app --host 0.0.0.0 --port 8000
"""
import io
import logging
import os
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import StreamingResponse

load_dotenv()

import stt
import tts
import vision

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("pocketlabel")

app = FastAPI(title="PocketLabel server")

CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.55"))


@app.get("/health")
def health():
    return {"status": "ok"}


def _respond(result: dict) -> StreamingResponse:
    if result["needs_reposition"] or result["confidence"] < CONFIDENCE_THRESHOLD:
        spoken = "I can't see that clearly. Try turning your head a little, or moving closer."
    else:
        spoken = result["spoken_summary"]

    audio_bytes = tts.synthesize(spoken)
    return StreamingResponse(
        io.BytesIO(audio_bytes),
        media_type="audio/mpeg",
        headers={
            "X-Spoken-Text": spoken,
            "X-Confidence": str(result["confidence"]),
            "X-Category": str(result["category"]),
        },
    )


@app.post("/ask")
async def ask(image: UploadFile = File(...), question_audio: Optional[UploadFile] = File(None)):
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

    if question:
        result = vision.answer_question(image_bytes, question, media_type=image.content_type or "image/jpeg")
    else:
        result = vision.read_label(image_bytes, media_type=image.content_type or "image/jpeg")

    logger.info("Vision result: %s", result)
    return _respond(result)


@app.post("/read_label")
async def read_label(image: UploadFile = File(...)):
    """No-audio path, for bench-testing before the mic is wired up."""
    image_bytes = await image.read()
    result = vision.read_label(image_bytes, media_type=image.content_type or "image/jpeg")
    logger.info("Vision result: %s", result)
    return _respond(result)
