"""
Vocalens server — glasses form factor.

/ask is the only path the glasses use. The wearer presses a button, which
records their question and captures a frame; both arrive here together and
are answered out loud. Flow:
  1. send the JPEG and the recorded question to the vision model in ONE
     call — the model hears the question and looks at the photo at the same
     time, so there is no separate speech-to-text round trip, and the model
     works out what was asked rather than a keyword classifier
  2. synthesize the answer and stream it back as RAW PCM: 16 kHz, 16-bit
     signed little-endian, mono, which the glasses write straight to their
     I2S DAC with no decoder

Set FUSE_AUDIO=0 to fall back to the older transcribe-then-ask path, which
is also used automatically if the fused call fails.

Every reply is also saved to audio_output/ as a WAV, and every frame to
captures/, so both ends of a round trip can be inspected after the fact.

Run: uvicorn main:app --host 0.0.0.0 --port 8000
"""
import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, Response, UploadFile
from fastapi.staticfiles import StaticFiles

load_dotenv()

import pcm
import profile_store
import stt_openrouter as stt
import timings
import tts_openrouter as tts
import vision_openrouter as vision

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("vocalens")

app = FastAPI(title="Vocalens server")
app.mount("/setup", StaticFiles(directory="static", html=True), name="setup")

CONFIDENCE_THRESHOLD = float(os.environ.get("CONFIDENCE_THRESHOLD", "0.55"))

# Send the recorded question straight to the vision model alongside the photo,
# instead of transcribing it first and sending the text. One network round
# trip instead of two — measured ~0.6-0.7s faster end to end.
#
# Only works if VISION_MODEL accepts audio input (google/gemini-3.5-flash-lite
# does). Set FUSE_AUDIO=0 to go back to transcribe-then-ask. A failure here
# falls back to that path automatically, so a model that can't do it costs a
# retry rather than a broken request.
FUSE_AUDIO = os.environ.get("FUSE_AUDIO", "1").strip().lower() not in ("0", "false", "no")

DEFAULT_USER_ID = "default"  # single-wearer device for the hackathon demo

# BENCH TEST: save every incoming photo to disk so you can actually look at
# what the camera saw. Not something you'd want in the real product (it
# would fill up storage and isn't needed for the flow to work) -- just handy
# while testing.
CAPTURES_DIR = Path(__file__).parent / "captures"
CAPTURES_DIR.mkdir(exist_ok=True)

# Every spoken reply is also written to audio_output/ as a WAV so there's a
# file to play back later, not just the PCM stream the glasses get.
AUDIO_DIR = Path(tts.OUTPUT_DIR)
AUDIO_DIR.mkdir(parents=True, exist_ok=True)

# TEMPORARY (mic bring-up): every recording the glasses upload is written
# here as a playable WAV, before anything is done with it. This is how you
# check the mic actually captured speech rather than silence or noise --
# transcription failing tells you nothing about which end was at fault.
# Delete this block and its use in ask() once the mic is trusted.
QUESTIONS_DIR = Path(__file__).parent / "questions"
QUESTIONS_DIR.mkdir(exist_ok=True)

def _question_wav(raw: bytes) -> tuple:
    """Return (wav_bytes, note, levels) for an uploaded recording.

    The firmware labels its part audio/wav, but what mic_capture.h actually
    produces is bare 16 kHz mono 16-bit samples with no RIFF header. The
    transcription API needs a real container, so anything that isn't already
    a WAV is treated as raw PCM at the firmware's rate and wrapped here.
    Detection is by the RIFF magic rather than by the filename, since the
    filename is whatever the client felt like sending.

    The samples also arrive far too quiet to transcribe — the PDM mic peaks
    a few hundred out of 32767 at speaking distance, on a DC offset of about
    a thousand. pcm.normalise() centres and scales them by whatever factor
    this particular recording needs, so the same code works in a quiet room
    and a loud one without a gain constant to re-tune. It is done here
    rather than on the board so it can be changed without a reflash."""
    if raw[:4] == b"RIFF":
        return raw, "already WAV", pcm.level_report(raw[44:])

    levels = pcm.level_report(raw)
    loud, gain = pcm.normalise(raw)
    note = f"raw PCM at {pcm.TARGET_RATE} Hz, gain {gain}x"
    if gain == 1.0:
        note += " (left alone — already loud enough, or silence)"
    return pcm.pcm_to_wav(loud, pcm.TARGET_RATE), note, levels


def _save_capture(image_bytes: bytes, tag: str = "") -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    suffix = f"_{tag}" if tag else ""
    path = CAPTURES_DIR / f"{stamp}{suffix}.jpg"
    path.write_bytes(image_bytes)
    logger.info("Saved capture: %s", path.name)
    return path


def _speak(spoken: str, confidence: float = 1.0, category: Optional[str] = None,
           timer: Optional[timings.Timer] = None) -> Response:
    """Synthesize and return RAW PCM — 16 kHz, 16-bit signed little-endian,
    mono. No container, no compression: the glasses write these bytes
    straight at their I2S DAC, so there is no decoder on the device.

    Every /ask path ends here, so this is also where the latency report is
    printed — one per request, whatever route through ask() produced it."""
    timer = timer or timings.Timer()

    with timer.stage("tts", f"{tts.MODEL} / {tts.VOICE}"):
        pcm_bytes = tts.synthesize(spoken)

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    audio_path = AUDIO_DIR / f"reply_{stamp}.wav"
    audio_path.write_bytes(pcm.pcm_to_wav(pcm_bytes, tts.SAMPLE_RATE))
    logger.info("Spoken: %r -> %s (%.1fs, %d bytes PCM)", spoken,
                audio_path.name, pcm.duration_seconds(pcm_bytes), len(pcm_bytes))

    # Printed before the bytes go out, so the number is server-side latency:
    # it excludes streaming the reply down to the glasses and playing it.
    timer.report(f"speech produced: {pcm.duration_seconds(pcm_bytes):.1f}s of audio")

    # Response, NOT StreamingResponse: Starlette never sets Content-Length on
    # a streamed body, it sends Transfer-Encoding: chunked. The firmware reads
    # the raw socket via getStreamPtr(), which does not de-chunk, so it relies
    # on Content-Length to know how much to buffer — getSize() returns -1 on a
    # chunked reply and playPcmStream() refuses the body and plays nothing.
    # The whole reply is in memory here anyway, so there is nothing to stream.
    return Response(
        content=pcm_bytes,
        # Bare samples, so a generic binary type. The rate/width/channels
        # are fixed by agreement with the firmware, and echoed in headers
        # for anything else that wants to consume this.
        media_type="application/octet-stream",
        headers={
            "Content-Length": str(len(pcm_bytes)),
            "X-Spoken-Text": spoken,
            "X-Confidence": str(confidence),
            "X-Category": str(category),
            "X-Sample-Rate": str(tts.SAMPLE_RATE),
            "X-Bits-Per-Sample": "16",
            "X-Channels": "1",
        },
    )


def _speak_vision_result(result: dict, timer: Optional[timings.Timer] = None) -> Response:
    if result["needs_reposition"] or result["confidence"] < CONFIDENCE_THRESHOLD:
        spoken = "I can't see that clearly. Try turning your head a little, or moving closer."
    else:
        spoken = result["spoken_summary"]
    return _speak(spoken, result["confidence"], result["category"], timer=timer)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/ask")
async def ask(
    image: UploadFile = File(...),
    question_audio: Optional[UploadFile] = File(None),
    question_text: Optional[str] = Form(None),
    user_id: str = Form(DEFAULT_USER_ID),
):
    # Starts the clock as early as possible: everything after this point is
    # inside the measured request. The upload itself is already partly done
    # by the time FastAPI calls us, so "upload" below is only the tail of it.
    timer = timings.Timer("/ask")

    # The report lives in a finally so it prints on EVERY request, not just
    # the ones that reach _speak(). A vision or TTS call that raises is the
    # case most worth timing, and that path returns a 500 without ever
    # getting there. Timer.report() only prints once, so the normal path
    # still reports from _speak() with its audio-duration note attached.
    try:

        with timer.stage("upload"):
            image_bytes = await image.read()
        logger.info("Received frame: %d bytes", len(image_bytes))
        timer.note("upload", f"{len(image_bytes)} bytes JPEG")
        with timer.stage("save_capture"):
            _save_capture(image_bytes, tag="ask")

        # The mic is the question now: the button press records, and what it
        # recorded arrives here as question_audio. question_text is still
        # accepted after it, so curl or a script can drive this endpoint with no
        # mic involved.
        question = None
        # Set instead of `question` when the audio is going to the vision
        # model as audio. Exactly one of the two is ever populated.
        question_wav = None

        if question_audio is not None:
            with timer.stage("audio_upload"):
                raw = await question_audio.read()
            if raw:
                with timer.stage("audio_prep", "decode + normalise"):
                    wav_bytes, note, levels = _question_wav(raw)

                # TEMPORARY (mic bring-up): keep the recording. Play it to hear
                # exactly what the glasses heard.
                stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                q_path = QUESTIONS_DIR / f"question_{stamp}.wav"
                q_path.write_bytes(wav_bytes)
                logger.info("Recording: %s — %d bytes in, %s, %.1fs audio",
                            q_path.name, len(raw), note,
                            pcm.duration_seconds(wav_bytes[44:]))
                # Speech-to-noise, not an absolute level: the same number means
                # the same thing in a quiet room and a noisy one. Roughly, under
                # 6 dB means nobody spoke (or the mic didn't hear them), and
                # ordinary speech lands well above 15 dB.
                logger.info("  levels: peak %d, floor %.1f, loudest %.1f, "
                            "speech-to-noise %.1f dB, dc %.1f",
                            levels["peak"], levels["floor"], levels["loudest"],
                            levels["snr_db"], levels["dc"])
                if levels["snr_db"] < 6:
                    logger.warning("  that is close to silence — play the WAV "
                                   "before blaming the transcription")

                clip_seconds = pcm.duration_seconds(wav_bytes[44:])

                # Fusing sends this audio to the vision model as audio, so
                # hold on to the bytes rather than spending a round trip
                # turning them into text first.
                if FUSE_AUDIO:
                    question_wav = wav_bytes
                    logger.info("Fusing audio into the vision call (%.1fs clip) "
                                "— skipping the separate STT round trip",
                                clip_seconds)
                else:
                    try:
                        with timer.stage("stt", stt.MODEL):
                            question = stt.transcribe(wav_bytes, filename=q_path.name)
                        logger.info("Transcribed question: %r", question)
                        timer.note("stt", f"{stt.MODEL} -> {question!r}")
                    except Exception:
                        logger.exception("Transcription failed, falling back to default question")
            else:
                logger.warning("question_audio present but empty — mic recorded nothing")

        if not question and question_text:
            question = question_text
            question_wav = None  # explicit text wins over the recording
            logger.info("Question (from client): %r", question)

        user_context = profile_store.dosage_context_summary(user_id)
        media_type = image.content_type or "image/jpeg"

        if question_wav is not None:
            # Fused path: photo and recorded question in one call, no STT.
            try:
                with timer.stage("vision+audio", vision.MODEL):
                    result = vision.answer_audio_question(
                        image_bytes, question_wav, media_type=media_type,
                        user_context=user_context,
                    )
                # The model reports back what it heard, so a misheard question
                # is still visible in the log rather than showing up only as a
                # strange answer.
                heard = result.get("heard")
                logger.info("Heard (fused): %r", heard)
                timer.note("vision+audio", f"{vision.MODEL} <- {heard!r}")
            except Exception:
                # Most likely the model doesn't take audio. Fall back to the
                # two-call path rather than failing the request.
                logger.exception("Fused audio+image call failed — falling back "
                                 "to transcribe-then-ask")
                question_wav_local = question_wav
                question_wav = None
                with timer.stage("stt", stt.MODEL):
                    question = stt.transcribe(question_wav_local, filename="question.wav")
                logger.info("Transcribed question: %r", question)

        if question_wav is None:
            with timer.stage("vision", vision.MODEL):
                if question:
                    result = vision.answer_question(
                        image_bytes, question, media_type=media_type, user_context=user_context
                    )
                else:
                    result = vision.read_label(
                        image_bytes, media_type=media_type, user_context=user_context
                    )

        logger.info("Vision result: %s", result)
        return _speak_vision_result(result, timer=timer)
    finally:
        timer.report()


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
