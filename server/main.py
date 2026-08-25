"""
PocketLabel server. Receives a single JPEG frame from the XIAO ESP32S3 Sense,
runs one Claude vision call to read the label, synthesizes a short spoken
response, and streams the audio back.

Run: uvicorn main:app --host 0.0.0.0 --port 8000
"""
import io
import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import StreamingResponse

load_dotenv()

import tts
import vision

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("pocketlabel")

app = FastAPI(title="PocketLabel server")

CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.55"))


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/read_label")
async def read_label(image: UploadFile = File(...), distance_mm: int = Form(0)):
    image_bytes = await image.read()
    logger.info("Received frame: %d bytes, distance=%dmm", len(image_bytes), distance_mm)

    result = vision.read_label(image_bytes, media_type=image.content_type or "image/jpeg")
    logger.info("Vision result: %s", result)

    if result["needs_reposition"] or result["confidence"] < CONFIDENCE_THRESHOLD:
        spoken = "I can't read that clearly. Try moving a little closer or steadier."
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
