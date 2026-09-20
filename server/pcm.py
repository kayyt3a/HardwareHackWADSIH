"""
pcm.py

Audio format helpers for the raw-PCM speaker path.

The glasses write samples straight at an I2S DAC, so what the firmware wants
is the simplest possible thing: 16 kHz, 16-bit signed little-endian, mono,
with no container and no decoder. This module turns whatever the TTS
provider hands back (a WAV, usually at a higher rate and sometimes stereo)
into exactly that.

Everything here is pure standard library — no numpy, no ffmpeg — because
this runs on a laptop at a hackathon and a missing binary at the wrong
moment is not worth the fidelity. A linear-interpolation resample is
audibly fine for speech at these rates.
"""

import array
import io
import math
import struct
import wave

# What the firmware's I2S output is configured for. Change both ends
# together if you ever change this.
TARGET_RATE = 16000
TARGET_WIDTH = 2   # bytes per sample (16-bit)
TARGET_CHANNELS = 1


class PcmError(Exception):
    pass


def _to_mono(samples: list, channels: int) -> list:
    """Average interleaved channels down to one."""
    if channels == 1:
        return samples
    out = []
    for i in range(0, len(samples) - channels + 1, channels):
        out.append(sum(samples[i:i + channels]) // channels)
    return out


def _resample(samples: list, src_rate: int, dst_rate: int) -> list:
    """Linear interpolation. Good enough for speech, and dependency-free."""
    if src_rate == dst_rate or not samples:
        return samples

    ratio = src_rate / dst_rate
    out_len = int(len(samples) / ratio)
    out = []
    for i in range(out_len):
        pos = i * ratio
        left = int(pos)
        right = min(left + 1, len(samples) - 1)
        frac = pos - left
        out.append(int(samples[left] * (1.0 - frac) + samples[right] * frac))
    return out


def wav_to_pcm(wav_bytes: bytes) -> bytes:
    """WAV container -> raw 16 kHz mono 16-bit little-endian samples."""
    if not wav_bytes[:4] == b"RIFF":
        raise PcmError(
            "Expected a WAV from the TTS provider but got something else "
            f"(starts with {wav_bytes[:4]!r}). Check TTS_FORMAT in .env — "
            "the raw-PCM path can't decode MP3."
        )

    with wave.open(io.BytesIO(wav_bytes), "rb") as w:
        channels = w.getnchannels()
        width = w.getsampwidth()
        rate = w.getframerate()
        frames = w.readframes(w.getnframes())

    if width != 2:
        raise PcmError(f"Need 16-bit audio, got {width * 8}-bit.")

    count = len(frames) // 2
    samples = list(struct.unpack("<" + "h" * count, frames[:count * 2]))

    samples = _to_mono(samples, channels)
    samples = _resample(samples, rate, TARGET_RATE)

    return struct.pack("<" + "h" * len(samples), *samples)


def raw_to_pcm(raw_bytes: bytes, src_rate: int, channels: int = 1) -> bytes:
    """Bare samples (no container) -> raw 16 kHz mono 16-bit little-endian.

    Used when the provider returns response_format="pcm", which has no header
    to describe itself — the rate has to be told to us, which is why the
    request asks for a specific one and TTS_SOURCE_RATE exists as an escape
    hatch if a provider ignores that."""
    count = len(raw_bytes) // 2
    if not count:
        raise PcmError("Provider returned no audio.")

    samples = list(struct.unpack("<" + "h" * count, raw_bytes[:count * 2]))
    samples = _to_mono(samples, channels)
    samples = _resample(samples, src_rate, TARGET_RATE)
    return struct.pack("<" + "h" * len(samples), *samples)


def to_pcm(audio_bytes: bytes, src_rate: int, channels: int = 1) -> bytes:
    """Accept either a WAV or bare samples and normalise to the target
    format. Which one came back depends on the response_format the provider
    honoured, so sniff rather than assume."""
    if audio_bytes[:4] == b"RIFF":
        return wav_to_pcm(audio_bytes)
    return raw_to_pcm(audio_bytes, src_rate, channels)


def pcm_to_wav(pcm_bytes: bytes, rate: int = TARGET_RATE) -> bytes:
    """Wrap raw PCM back in a WAV container, so the same audio that went to
    the glasses can be double-clicked on the desktop."""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(TARGET_CHANNELS)
        w.setsampwidth(TARGET_WIDTH)
        w.setframerate(rate)
        w.writeframes(pcm_bytes)
    return buf.getvalue()


def duration_seconds(pcm_bytes: bytes, rate: int = TARGET_RATE) -> float:
    return len(pcm_bytes) / (rate * TARGET_WIDTH * TARGET_CHANNELS)


# --- microphone levels -----------------------------------------------------
#
# The onboard PDM mic sits a long way below full scale at speaking distance:
# a recording of ordinary speech comes back with peaks of a few hundred out
# of 32767, on top of a constant DC offset of a thousand or so. Played or
# transcribed as-is it is effectively silence.
#
# Rather than a fixed gain, which only suits the room it was tuned in, the
# level is measured and the recording scaled to a target peak. A quiet room
# gets a lot of gain and a loud one gets little, with no threshold to
# re-tune when the environment changes.

# Fraction of full scale the loudest sample is scaled to. Not 1.0: leaves
# headroom so nothing clips if the next recording is a shade louder.
NORMALISE_TARGET = 0.7

# Ceiling on the multiplier. High, because this mic genuinely needs a few
# hundred times: measured speech peaks around 60 counts out of 32767. What
# keeps silence from being amplified into a room of hiss is MIN_SNR_DB
# below, not this — a ratio test holds in any room, where a gain ceiling
# tuned for one room does not.
NORMALISE_MAX_GAIN = 512.0

# Speech-to-noise, in dB, below which a recording is left alone. Amplifying
# noise only makes it loud noise, and transcription models will invent words
# out of it. Measured on this build: ambient floor ~9, ordinary speech ~80,
# which is about 19 dB.
MIN_SNR_DB = 6.0

# Absolute floor: below this the mic is dead, not quiet. A ratio test can't
# catch that case, because noise against noise is still a ratio.
SILENCE_PEAK = 4

# The first moments of a recording are the I2S DMA starting up: the samples
# come back at zero while the mic's DC offset is a thousand or so, which
# reads as one enormous transient. Left in, it becomes the peak, and the
# whole recording gets scaled against a click instead of against the voice.
# Skipped for measurement only — the audio itself is not trimmed.
LEAD_IN_MS = 250

# Peak is taken at this percentile rather than as the absolute maximum, so a
# single click (a knock on the frame, a button) can't swallow the gain the
# speech needed.
PEAK_PERCENTILE = 0.995


def _samples(pcm_bytes: bytes) -> array.array:
    a = array.array("h")
    a.frombytes(pcm_bytes[: len(pcm_bytes) - (len(pcm_bytes) % 2)])
    return a


def _measurable(s: array.array, rate: int) -> array.array:
    """The part of a recording worth measuring: everything after the DMA
    start-up transient. Falls back to the whole thing if it is shorter."""
    lead = int(rate * LEAD_IN_MS / 1000)
    return s[lead:] if len(s) > lead * 2 else s


def _peak(s: array.array, dc: float) -> int:
    """Level at PEAK_PERCENTILE, so one click doesn't define the recording."""
    if not s:
        return 0
    mags = sorted(abs(v - dc) for v in s)
    return int(mags[min(len(mags) - 1, int(len(mags) * PEAK_PERCENTILE))])


def level_report(pcm_bytes: bytes, rate: int = TARGET_RATE,
                 window_ms: int = 20) -> dict:
    """Measure a recording: DC offset, peak, noise floor and speech-to-noise.

    The floor is the quietest 10% of short windows, which is the room with
    nobody talking, and `snr_db` is the loudest window against it. That
    ratio is what says whether anyone spoke — unlike an absolute peak, it
    means the same thing in a quiet room and a noisy one."""
    s = _measurable(_samples(pcm_bytes), rate)
    n = len(s)
    if not n:
        return {"dc": 0, "peak": 0, "floor": 0, "loudest": 0, "snr_db": 0.0}

    dc = sum(s) / n
    peak = _peak(s, dc)

    win = max(1, int(rate * window_ms / 1000))
    rms = []
    for i in range(0, n - win + 1, win):
        acc = 0.0
        for j in range(i, i + win):
            d = s[j] - dc
            acc += d * d
        rms.append(math.sqrt(acc / win))
    if not rms:
        rms = [0.0]
    rms.sort()

    floor = rms[max(0, int(len(rms) * 0.1))]
    loudest = rms[-1]
    snr_db = 20 * math.log10(loudest / floor) if floor > 0 and loudest > 0 else 0.0

    return {"dc": round(dc, 1), "peak": int(peak), "floor": round(floor, 1),
            "loudest": round(loudest, 1), "snr_db": round(snr_db, 1)}


def normalise(pcm_bytes: bytes, target: float = NORMALISE_TARGET,
              max_gain: float = NORMALISE_MAX_GAIN,
              rate: int = TARGET_RATE) -> tuple:
    """Remove the DC offset and scale the peak to `target` of full scale.

    Returns (pcm_bytes, gain). The gain is whatever THIS recording needs, so
    a quiet room gets a lot and a loud one gets little — there is no level
    constant to re-tune when the environment changes.

    A gain of 1.0 means it was left alone: it was already loud enough, or it
    failed the MIN_SNR_DB test and is noise rather than speech."""
    s = _samples(pcm_bytes)
    n = len(s)
    if not n:
        return pcm_bytes, 1.0

    # Measured on the settled part, applied to all of it.
    settled = _measurable(s, rate)
    dc = int(sum(settled) / len(settled))
    peak = _peak(settled, dc)
    if peak < SILENCE_PEAK:
        return pcm_bytes, 1.0

    # The proportional test: is anything louder than the room's own floor?
    if level_report(pcm_bytes, rate)["snr_db"] < MIN_SNR_DB:
        return pcm_bytes, 1.0

    gain = min(max_gain, target * 32767 / peak)
    if gain <= 1.0:
        gain = 1.0

    for i in range(n):
        v = int((s[i] - dc) * gain)
        s[i] = -32768 if v < -32768 else (32767 if v > 32767 else v)
    return s.tobytes(), round(gain, 1)


def speed_up(pcm_bytes: bytes, factor: float) -> bytes:
    """Play `factor` times faster by resampling: keep fewer samples and let
    the board's fixed 16 kHz clock get through them sooner.

    Pitch rises with tempo, because the waveform itself is compressed — the
    same trick otto_finder uses deliberately to make a small robot voice.
    Above about 1.3 it starts to sound like one. This is the fallback for
    when the provider won't take a `speed` parameter; when it will, the
    model re-reads the line faster at its own pitch, which sounds better."""
    if abs(factor - 1.0) < 0.01:
        return pcm_bytes

    src = _samples(pcm_bytes)
    if len(src) < 2:
        return pcm_bytes

    n_out = int((len(src) - 1) / factor)
    out = array.array("h", bytes(2 * n_out))
    for i in range(n_out):
        pos = i * factor
        j = int(pos)
        frac = pos - j
        out[i] = int(src[j] + (src[j + 1] - src[j]) * frac)
    return out.tobytes()
