# Vocalens — full project context (handoff prompt)

> Paste everything below this line into ChatGPT (or any other assistant) as your
> first message. It is written to be self-contained: it assumes the reader has
> never seen this project.

---

You are helping my four-person team plan and build a hardware/AI project for a
hackathon. Read this entire brief before responding. At the end I'll tell you
what I want help with. Ask me clarifying questions if something is genuinely
ambiguous, but don't re-litigate decisions marked as **locked**.

## The event

- **Hardware Hack 2026**, hosted by WADSIH (WA Data Science Innovation Hub) at
  Innovation Central Perth, Curtin University.
- Team name: **FourSight** — 4 members, ~4 weeks including workshops.
- We are entering **Challenge 1C — "Eyes for Labels"**: assistive technology
  for people with low vision reading labels and packaging.
- There is also an OpenRouter-sponsored track, so LLM API usage is encouraged.
- Final demo slot is **~3 minutes**, plus judged pitch.

### Constraints from the challenge brief (these are hard rules)

1. "Do not use anybody's real medical or medication information in your
   prototype. **Use synthetic data and your own team as test users.**"
2. "Your prototype is **not a medical device**. Do not make clinical claims."
3. "Language matters in your pitch — describe what the device does and who it
   is for; **avoid framing people as problems to be managed**."
4. The brief specifically warns that **mounting/physical attachment** is the
   thing teams most often underestimate.
5. The brief judges **whether it looks like something a person would wear**.

## The product: Vocalens

**Three-sentence version:** Vocalens is a pair of clip-on pods that attach to
glasses you already own. You tap your temple (or eventually say a wake word),
it photographs whatever you're looking at, and a vision-language model reads it
back to you through a small speaker behind your ear. It also scans barcodes,
reads expiry dates and dosage labels, and remembers a small amount of
personal information you tell it, so answers are tailored to you.

**Why glasses, not a handheld** (locked decision): elderly users lose handheld
devices constantly. Glasses are already glued to their head. The whole product
thesis is *the device is where their eyes already are*.

**Architecture** (borrowed from an existing project called `otto_finder`):
dumb board, server-side intelligence. Camera → WiFi → server → VLM → audio
back. The ESP32 does almost no thinking.

## Hardware — what we actually have

**Locked constraint: ZERO external purchases.** Everything is built from:

- **Seeed XIAO ESP32S3 Sense** — camera, PDM mic, WiFi/BLE, PSRAM
- **Freenove Ultimate Starter Kit** — which importantly contains a **Speaker**
  and an **Audio Converter & Amplifier** module, plus jumper wires (65 M-M,
  20 F-F, 20 F-M), battery holders, etc.
- A **Snapmaker U1** 3D printer — 270×270×270mm FDM, multi-material (4 spools).
  Available filaments: **PLA, PETG, TPU**.
- An ordinary pair of glasses to clip onto.

Things we deliberately did NOT buy and instead demoted to "what we'd build
next" pitch material: a bone-conduction transducer, a longer FPC camera ribbon,
sheathed/hidden cabling.

### Physical design (already CAD'd, validated, and printing)

Two pods connected by 5 jumper wires (I2S: BCLK, LRC, DIN, 3V3, GND) running
~10cm along the temple arm. I2S is slow serial, so jumper wires are
electrically fine at that length — this is how we got a two-pod split without
buying a ribbon.

- **Front pod** (near hinge): XIAO + camera (camera stays on its stock ribbon,
  positioned *beside* the board rather than stacked on it) + capacitive touch
  pad. 48 × 10 × 29 mm.
- **Rear pod** (behind ear): audio amp + speaker. 57 × 10 × 38 mm.

**The single most important geometry insight**, learned the hard way after a
failed first design:

> A temple arm sits right against the skull. There is almost **no clearance
> above or below** it before you hit hair or bone. There is **plenty of
> clearance straight outward**, away from the head. So a component's
> **thickness** (PCB profile, speaker depth — a few mm) is what may add to the
> pod's **vertical** extent, and a component's **footprint** (28mm speaker
> diameter, 19mm board width) must extend **outward** instead.

Getting this backwards made the pods 22mm and 31mm tall and they pressed into
the wearer's head. Fixing it brought both to ~10mm vertical. The CAD source
(`hardware/cad/vocalens_pod.scad`, OpenSCAD, fully parametric) documents the
axis convention in a comment block at the top:

```
X (length)  — along the temple arm, front to back.
Y (BODY_W)  — the arm's TOP-TO-BOTTOM axis. KEEP SMALL. Pass THICKNESS here.
Z (cav_h)   — straight out away from the head. Real clearance. Pass FOOTPRINT here.
```

Materials decision: **bases in TPU** (the base is what flexes on every
clip-on/off — TPU doesn't fatigue-crack and forgives errors in the snap-fit
tolerance), **lids in PETG** (rigid, doesn't flex), **PLA for disposable
fit-test iterations**. The clip grips by spring tension only; a `SNAP_GAP`
parameter is tuned by printing a ~3-minute `fit_test.stl` repeatedly.

All STLs verified watertight/manifold using `trimesh` (`is_watertight`), after
a homemade edge-counting checker gave false positives. Note: **OpenSCAD
silently evaluates unknown variables as `undef` without erroring**, which once
produced genuinely broken plate STLs after a variable rename.

### Known rough edges (we state these openly in the pitch)

- Jumper wires run **exposed** along ~10cm of the temple arm. Not hidden, not
  strain-relieved.
- Pods extend visibly outward (29–38mm) — the deliberate trade for staying thin
  vertically. Looks like a small clipped-on camera, not a flush accessory.
- Utilitarian bar shape with only 1mm corner rounding.
- No strain relief where cables exit.

## Software — what exists

### `server/` (Python, FastAPI) — complete and syntax-verified

- **`main.py`** — endpoints:
  - `POST /ask` — image + optional `question_audio` + `user_id` form field.
    Flow: transcribe → classify intent → recall / remember / ask → barcode
    fast path → vision call → TTS.
  - `POST /read_label` — no-audio bench path for testing with `curl`.
  - `GET /health`, `GET|POST /profile/{user_id}`
  - `/setup` — serves a static HTML profile-setup page.
- **`vision.py`** — Claude vision (`claude-sonnet-5`). System prompt returns
  JSON `{spoken_summary, category, confidence, needs_reposition}` and
  **explicitly forbids medical verdicts**.
- **`profile_store.py`** — JSON-backed per-user profiles. Two modes via
  `profile_type`: `"dosage"` (age, weight, allergies) and `"reminders"`
  (saved events). **Critical design point:** `dosage_context_summary()`
  returns `None` unless `profile_type == "dosage"` — health facts are never
  *assembled* in reminders mode, not merely filtered later.
- **`intent.py`** — trigger phrases: remember = `["remember this",
  "remember that", "save this", "add this"]`; recall = `["what do i have",
  "what's coming up", "what did i save", "what have i saved",
  "read my reminders", "what's on my list"]`.
- **`barcode.py`** — `pyzbar` + **Open Food Facts** lookup as a fast path
  *before* spending a VLM call. (Needs the system `zbar` library installed.)
- **`stt.py`** — Whisper. **`tts.py`** — OpenAI TTS.

### `firmware/` (PlatformIO, C++)

`main.cpp` (trigger → record → capture → multipart POST to `/ask` → play MP3),
`pins.h` (touch pad GPIO 3, I2S BCLK 7 / LRC 8 / DIN 9), plus **stubs**:
`wake_word.h` (ESP-SR / WakeNet — the highest-risk item in the project),
`mic_capture.h`, `offline_fallback.h`. `audio_playback.cpp` has a TODO for the
LittleFS path.

Gotcha: PSRAM must be set to **OPI PSRAM** or the camera won't init.

### Bring-up order (deliberately staged so nothing is debugged at 2am)

1. Camera only, on the bench → confirm server receives a frame
2. Audio out, short wires → confirm reply plays
3. Extend to full temple-length wires, clip on, retest
4. Mic in → confirm transcription
5. **Wake word last** — touch pad already gives a working demo without it

## The two personas (for the pitch)

**Margaret, 78 — synthetic, the demo persona. `profile_type = "dosage"`.**
Bayswater, 31 years in the same house, retired primary school teacher, does the
crossword with a lit magnifier, hosts book club. Age-related macular
degeneration for six years — central vision largely gone, peripheral intact, so
she navigates her home confidently but can't read anything she looks directly
at. Nine daily medications, kept in a self-invented order on the windowsill,
rechecked by position. Two bottles are the same size and shape; **she has a
rubber band round one of them.**

> The key pitch line: *"The baseline isn't nothing. It's a rubber band round a
> pill bottle."* — a system she invented, maintains, and which fails silently
> the moment someone tidies the windowsill.

Her question for us: *"What happens when it gets it wrong?"* — she can't check
the answer. This is why a confidence gate exists and why we deliberately demo
a failure.

**Ethan — a REAL teammate, the second configuration. `profile_type =
"reminders"`.** CS student, commutes by train, phone constantly in hand,
entirely tech-fluent.

> **Ethical constraint (locked):** do NOT attribute low vision to him as fact.
> The honest framing, which is also the *stronger* one:
> *"Ethan's on our team — CS student, commutes in, lives on his phone. He
> doesn't have low vision. But when we asked what a younger user would need
> from this, he's who we designed around, and he's the one who's actually been
> wearing it."*

His value is that he's the **hardest** user, not the most sympathetic: a
tech-fluent 20-something who'd say it's pointless if his phone already did it.
His moment: on the train, standing, coffee in one hand, a poster he'd never
unlock his phone for — he taps his temple instead. His question: *"Why would I
use this instead of my phone?"* Answer: hands-free, no unlock, no app, same
device that already does his reading.

Pitch guidance: lead with Margaret, bring in Ethan on one late slide, **do not
demo both live** (doubles setup and doubles what can break in 3 minutes).

## The pitch deck (8 slides, built with pptxgenjs)

Title → Margaret + stat → One device two people → Meta rebuttal → LIVE DEMO →
How it works → Dignity + cost → What's next. Palette: navy `0B4F6C`, teal
`137A7F`, amber `F2A65A`.

**The Meta Ray-Ban rebuttal** (a judge will ask this): *"Why would you buy Meta
glasses for $750 when you could spend under $100?"* Plus: they're a general
consumer device with assistive features bolted on; this is built around the
dosage/expiry use case, stores per-user context, runs on frames the user
already owns and already fits their face, and deliberately refuses to give
medical verdicts.

## Team split (4 people, `TEAM_ROLES.md`)

- **A — Firmware:** the board captures and speaks on demand. Wake word is
  timeboxed to week 3; if it isn't working, ship the touch pad and say so.
- **B — Server/AI:** the answer is right, or honestly says it isn't. Gets
  `/read_label` working from curl'd photos in week 1, *before* A has hardware —
  this de-risks the whole AI half independently.
- **C — Hardware:** it fits on a face and stays there. Owns CAD, printer,
  assembly, and how it looks (the brief judges this).
- **D — Demo & pitch:** owns the deck, the persona, and — most importantly —
  **integration testing**. This is not the "non-technical" role; D is the only
  person testing the whole system as a user would.

**Feature freeze at end of week 3** is the most important line in the plan.

## Where we are right now

Done: full CAD (validated, watertight), full server code, firmware skeleton
with stubs, 8-slide deck, personas doc, team roles doc, build guide.

In progress / next: print `fit_test.stl` → tune `SNAP_GAP` → print bases (TPU)
and lids (PETG); flash the XIAO; stand up the server; wire amp + speaker;
verify the no-medical-advice guardrail with a fake `dosage` profile.

Remaining risk list, in order: **wake word (ESP-SR)** > latency under venue
WiFi > snap-fit tolerance on real glasses > demo-night reliability.

---

## What I want from you

[REPLACE THIS SECTION with your actual ask, e.g.:]

- Stress-test the pitch narrative and tell me what a judge will attack.
- Help me plan weeks 2–4 in detail.
- Suggest what to do about the wake word if ESP-SR doesn't work.
- Poke holes in the enclosure design.
