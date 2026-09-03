# Vocalens — project context

Context file for anyone (human or AI) picking this repo up. Facts and the
reasoning behind decisions, not a tutorial. Step-by-step guides live in
`hardware/*.pdf`.

---

## The product, in three sentences

Two 3D-printed pods clip onto the temple arm of glasses the wearer already
owns. A trigger (touch pad, button, or eventually a wake word) makes the
camera photograph whatever they're looking at; the image goes over WiFi to a
laptop, a vision-language model reads it, and the answer comes back as speech
through a small speaker behind the ear.

It also scans barcodes, reads expiry dates and dosage labels, and holds a
small per-user profile so answers can be tailored.

## The event and the brief

- **Hardware Hack 2026**, WADSIH, Innovation Central Perth (Curtin).
- Team **FourSight**, 4 people, ~4 weeks.
- **Challenge 1C — "Eyes for Labels"**: assistive tech for people with low
  vision reading labels and packaging.
- Demo slot is **~3 minutes**.

### Rules from the brief that constrain the build

These are not preferences. Breaking them costs credibility with judges.

1. **No real medical or medication data.** Synthetic personas only; the team
   are the test users.
2. **Not a medical device. No clinical claims.**
3. **Language matters** — describe what the device does and who it's for.
   Never frame people as problems to be managed.
4. Mounting/physical attachment is the thing teams most often underestimate.
5. Whether it looks like something a person would actually wear is judged.

---

## Locked decisions, and why

Don't relitigate these without a new reason.

| Decision | Why |
|---|---|
| **Glasses, not handheld** | Elderly users lose handheld devices. Glasses are already on the face. This is the whole product thesis. |
| **Clip onto existing frames** | Sidesteps hinge/nose-bridge/lens fit entirely. A frame that already fits a real face solves mounting for free. |
| **Zero external purchases** | Everything from the Freenove Ultimate Starter Kit + XIAO ESP32S3 Sense. No shipping risk, no budget beyond what every team got. |
| **Dumb board, smart server** | The ESP32 only captures and plays. All intelligence is server-side Python, so the smart half can be fixed without reflashing. |
| **Two pods, not one** | One box of all five components is a lump on the side of the head. Split keeps each pod thin, and puts the camera at the front and the speaker at the ear where they belong. |

### Demoted to "what we'd build next" (pitch material, not built)

Bone-conduction audio, a hidden/sheathed cable between pods, a longer FPC
ribbon to detach the camera from the board. All would improve the product;
none are needed for a working prototype, and saying so proactively reads as
scoping discipline rather than apology.

---

## Hardware

**Front pod** (near hinge): XIAO ESP32S3 Sense + camera + trigger.
**Rear pod** (behind ear): audio amplifier + speaker.
Joined by 5 jumper wires carrying I2S + power along the temple arm.

I2S is slow serial, so a ~10cm jumper-wire run is electrically fine. That's
what makes the two-pod split possible without buying a ribbon cable. The
honest cost is that the wires run **exposed** along the arm — name it in the
pitch before a judge notices it.

### The axis convention — read before touching the CAD

A temple arm sits against the skull. There is almost **no clearance above or
below** it before you hit hair or bone; there is **plenty straight outward**.

- **X** — along the arm, front to back.
- **Y (vertical)** — toward scalp and ear. **Keep small.** Pass a component's
  *thickness* here.
- **Z (outward)** — away from the head. Real clearance. Pass a component's
  *footprint* here.

Getting this backwards made the pods 22mm and 31mm tall and they pressed into
the wearer's head. Corrected, both are ~10mm. It is documented at the top of
`hardware/cad/vocalens_ring.scad` for the same reason it's here.

### The mount (v2, current)

The clip used to be moulded into the pod, which meant one pod fitted exactly
one thickness of temple arm and needed a tuning print. v2 splits the jobs:

- **`temple_ring()`** — thin-walled TPU collar, opening deliberately
  **undersized**, stretches onto the arm like a hair tie. If it doesn't grip,
  make the opening *smaller* or the wall *thinner* — never larger.
- **`pod_base()`** — rigid PETG box with a dovetail slot. Never touches the
  glasses.

They join by a dovetail: soft TPU rail into hard PETG slot, so the joint
self-tightens and print tolerance is absorbed by the soft part. The wall under
the rail is locally thickened so the rail keeps its dimensions while the thin
side walls do the stretching.

**Consequence:** you print pods once. A ring that doesn't grip is a 10-minute
reprint, not a 3-hour one with electronics glued in.

### Materials

TPU for anything that flexes (rings), PETG for anything that must hold its
shape (pods, lids), PLA for disposable test prints only.

---

## Hardware gotchas that have already cost time

| Gotcha | Detail |
|---|---|
| **Pad labels ≠ GPIO numbers** | On the XIAO, `pins.h` GPIO 7/8/9/3 are the pads printed **D8/D9/D10/D2**. Always wire by the printed label. |
| **PSRAM must be OPI** | `-DBOARD_HAS_PSRAM` alone is not enough; needs `board_build.arduino.memory_type = qio_opi`. Without it PSRAM never initialises and the camera fails with perfect wiring. |
| **ESP8266Audio must be pinned to 1.9.x** | 2.x targets ESP-IDF 5 (`driver/i2s_std.h`); this platform is arduino-esp32 2.0.17 / IDF 4.4 (`driver/i2s.h`). |
| **Touch polarity is chip-specific** | On the original ESP32 `touchRead()` *falls* on touch; on the S3 it *rises*. Run the selftest build — it measures and prints both the direction and a threshold. |
| **GPIO 3 is a strapping pin** | Fine in use, but don't hold a button on it down during power-up. GPIO 2 (pad `D1`) is the drop-in alternative. |
| **A GND pin takes more than one wire** | Every ground is the same node. Twist or solder several wires into one joint — that's normal, not a bodge. |

### Trigger options

`USE_PUSH_BUTTON` in `firmware/src/pins.h` selects.

- **Touch pad** — one wire to any scrap of metal, **no ground return**. Best
  when GND pins are spoken for and smallest in the pod. Needs calibration.
- **Button** — deterministic, nothing to calibrate, but needs two connections
  and a through-hole switch can't take a jumper socket directly.

---

## Software

All intelligence is in `server/`. The board doesn't know Claude exists.

| File | Role |
|---|---|
| `server/main.py` | Routes: `/ask`, `/read_label`, `/health`, `/profile/{id}`, `/setup` |
| `server/vision.py` | The vision call. System prompt forbids medical verdicts. |
| `server/barcode.py` | Barcode + Open Food Facts lookup, tried **before** any model call |
| `server/profile_store.py` | Per-user profile, two modes |
| `server/intent.py` | Classifies remember / recall / ask |
| `server/stt.py`, `tts.py` | Speech in, speech out |
| `firmware/src/main.cpp` | Trigger → capture → multipart POST → play reply |
| `firmware/src/selftest.cpp` | Diagnostic build; tests each subsystem separately |

**The hardware↔software contract is one HTTP POST.** `main.cpp` posts the
JPEG (plus optional audio) as multipart form data to `/ask` and plays the MP3
that comes back.

### The guardrail is structural, not a prompt instruction

`dosage_context_summary()` returns `None` unless `profile_type == "dosage"`.
In reminders mode, health facts are not filtered out downstream — **the code
path that would assemble them never runs.** There is no health data in that
configuration to leak.

Say it that way in the pitch. "We told the model not to" is weak; "the code
that would build it doesn't execute" is not.

The device **surfaces what is printed on the label. It never gives a
verdict.** On a poor image it says it can't see clearly rather than guessing —
which matters more than usual, because the user cannot check its answer.

---

## The two users

Full briefs in `docs/PERSONAS.md`.

**Margaret, 78** — synthetic, the demo persona. Macular degeneration, nine
daily medications, keeps them in a self-invented order on the windowsill with
a rubber band round one bottle to tell two identical ones apart.

> *"The baseline isn't nothing. It's a rubber band round a pill bottle."*

**Ethan** — a **real teammate**, the second configuration. Tech-fluent CS
student who'd say the device was pointless if his phone already did it, which
is exactly why he's useful: he's the hardest user, not the most sympathetic.

> **Do not attribute low vision to him as fact.** He's real. The honest
> framing is stronger anyway: *"He doesn't have low vision. But he's who we
> designed the younger configuration around, and he's the one who's actually
> been wearing it."*

---

## Status

| Area | State |
|---|---|
| Server + AI | Works. Testable with `curl` and no hardware at all. |
| Firmware | Builds and flashes. Wake word and mic capture are stubs. |
| Self-test build | Works. Flash `-e selftest` to find which subsystem is broken. |
| CAD | Ring + interlock, validated watertight, mate checked by boolean intersection. |
| Printed and assembled | In progress. |

### Known stale

`README.md` still describes bone-conduction audio and the wake word as the
primary trigger. Both were superseded — the build uses the kit speaker and a
manual trigger. **This file is the authority where they disagree.**

---

## Highest-value test, at any point

```bash
cd server && uvicorn main:app --host 0.0.0.0 --port 8000
curl -X POST http://localhost:8000/read_label -F "image=@box.jpg"
```

Proves the entire AI half with zero wiring involved. The two halves fail
independently, so this is worth running whenever hardware is misbehaving.

## Risks, ranked

1. **Wake word (ESP-SR)** — highest risk. Timeboxed. The manual trigger is a
   complete demo without it, and shipping that is a fine outcome.
2. Venue WiFi latency.
3. Ring grip on real glasses — the one thing not verifiable without the
   physical frames.
4. Demo-night reliability generally.

**Feature freeze at end of week 3.** Teams lose hackathons by adding a feature
on the last day and breaking the thing that already worked.

## Files that must never be committed

`server/.env`, `server/profiles.json`, `firmware/src/secrets.h`. All
gitignored. Keep it that way.
