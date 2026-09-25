# VocaLens — project context

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
| **Both working pods on ONE temple, ballast on the other** | Splitting them across temples needed ~35cm of wire around the back of the head, and the jumper wires are not that long. Camera and audio pods sit on one arm as originally built, with a short run between their facing ends. Balance is restored by a **third pod on the other temple holding coins** — same outer shell, no electronics, no openings. **This also removes the long-I2S risk entirely**, which was the largest electrical unknown in the build. |

### Demoted to "what we'd build next" (pitch material, not built)

Bone-conduction audio, a hidden/sheathed cable between pods, a longer FPC
ribbon to detach the camera from the board. All would improve the product;
none are needed for a working prototype, and saying so proactively reads as
scoping discipline rather than apology.

---

## Hardware

**Camera pod** (front of one temple, near the hinge): XIAO ESP32S3 Sense +
camera + trigger. Its aperture is in the **front end wall**, not the lid — the
camera looks forward along the arm, and a hole in the lid would point the lens
sideways out of the side of the wearer's head.

`front_box_base` / `front_box_lid` size it from the **assembled stack as
measured** — 15 x 19 x 40mm plus 0.5mm leeway — rather than from a parts list.
That is 22.7mm wide against the old pod's 34.2mm. USB-C exits through the lid
10mm from the front; the receptacle is 8.34 x 2.56mm, so the cutout is 10 x
4mm, cut loose on purpose because a board sitting free in a pod never lines up
with a hole as well as a drawing says.

**The 20c coin cannot be the trigger on this box.** Its lid is 21mm wide and
takes a 19mm pad at most, against the coin's 28.52mm — the old pod was 34.2mm
wide *because* of that coin. The pad is now 18 x 20mm for copper tape or foil:
same electrode area as a 5c, no mass, and flush in a 0.8mm pocket instead of
needing 2.5mm of lid to bury a coin in. The coin still has a home — the
ballast pod on the other temple is full of them.
**Audio pod** (behind it on the same arm): amplifier + speaker.
**Ballast pod** (the other temple): coins, nothing else.

The two working pods are joined by 5 jumper wires over ~10cm, which is what
I2S over unshielded wire is comfortably fine with. Each pod has exactly **one**
cable opening, on the end that faces the other; every other wall is closed.
The concealment tube that used to run around the back of the head is gone with
the arrangement that needed it.

### The ballast pod

Its outer dimensions are copied from the camera pod rather than sized to its
contents, and that is the point: from the outside it has to read as the same
object, or the glasses look like they have a lump on one side and a different
lump on the other. Only the openings differ — no lens aperture, no cable slots,
nothing goes in or out.

Coins lie flat and stack outward. The cavity is 43.5 x 31 x 18mm, so seven 20c
pieces fit — 79g, far more than the other side can weigh. **Balance is tuned by
how many coins go in, not by reprinting**, which is why it is deliberately
oversized. 5c is 2.83g, 10c 5.65g, 20c 11.30g, 50c 15.55g; mix to trim.

### The axis convention — read before touching the CAD

A temple arm sits against the skull. There is almost **no clearance above or
below** it before you hit hair or bone; there is **plenty straight outward**.

- **X** — along the arm, front to back.
- **Y (vertical)** — up and down along the side of the head.
- **Z (outward)** — away from the head. **This is the expensive one.**

**Boards stand on edge**, broad face parallel to the head: pass a component's
*footprint* to Y and its *thickness* to Z.

An earlier version of this file said the reverse — keep Y small, because the
pod presses into the scalp. **That was wrong, and it cost a design round.** The
pod cannot press into anything: the ring sits between it and the arm, so the
pod body starts ~12mm outboard and is centred on the arm. Growing it vertically
happens in free air.

Lying the 19mm board flat to protect a nonexistent constraint projected the
front pod **34mm** off the arm and the rear pod **43mm** — boxes on the side of
the head. On edge they are **24mm and 23mm**, and the bulk runs along the line
of the frame where it reads as a thick glasses arm.

The test to apply: *would a person see it?* Vertical is hidden by the frame and
the ear. Outward is the silhouette.

### The mount (v2, current)

The clip used to be moulded into the pod, which meant one pod fitted exactly
one thickness of temple arm and needed a tuning print. v2 splits the jobs:

- **`temple_ring()`** — thin-walled TPU collar, opening deliberately
  **undersized**, stretches onto the arm like a hair tie. If it doesn't grip,
  make the opening *smaller* or the wall *thinner* — never larger.
  **But there is a floor.** TPU grips best around 20-30% strain; past that the
  ring either won't go on at all or takes a permanent set and grips worse. An
  opening of 5.0 x 2.2mm failed on a real arm at roughly 120% strain. Target
  **75-85% of the arm's measured section**. `tpu_ladder` prints four graduated
  rings to find it empirically — all four carry an identical rail, so any of
  them fits the same pods.
- **`pod_base()`** — rigid PETG box with a dovetail slot. Never touches the
  glasses.

They join by a dovetail: soft TPU rail into hard PETG slot, so the joint
self-tightens and print tolerance is absorbed by the soft part. The wall under
the rail is locally thickened so the rail keeps its dimensions while the thin
side walls do the stretching.

**Consequence:** you print pods once. A ring that doesn't grip is a 10-minute
reprint, not a 3-hour one with electronics glued in.

### Materials

**TPU for the rings, PLA for the pods and lids.**

The rings are the one part where the material *is* the mechanism: they grip by
stretching onto the arm at 20-30% strain. PLA does not stretch, it snaps. That
substitution is never available, however convenient.

The pods were PETG and are now PLA. PLA is more brittle, but nothing in a pod
is under sustained load, and it buys two things: it prints better, and it
shares a bed temperature (~55-60C) with TPU, so both materials can run in one
job on a tool-changer. PETG at ~80C could not. `FINAL_combined_U1.stl` is that
single-file plate — eight separate bodies, so the slicer can be told which two
are TPU.

---

## Hardware gotchas that have already cost time

| Gotcha | Detail |
|---|---|
| **Pad labels ≠ GPIO numbers** | On the XIAO, `pins.h` GPIO 7/8/9/3 are the pads printed **D8/D9/D10/D2**. Always wire by the printed label. |
| **PSRAM must be OPI** | `-DBOARD_HAS_PSRAM` alone is not enough; needs `board_build.arduino.memory_type = qio_opi`. Without it PSRAM never initialises and the camera fails with perfect wiring. |
| **ESP8266Audio must be pinned to 1.9.x** | 2.x targets ESP-IDF 5 (`driver/i2s_std.h`); this platform is arduino-esp32 2.0.17 / IDF 4.4 (`driver/i2s.h`). |
| **Touch polarity is chip-specific** | On the original ESP32 `touchRead()` *falls* on touch; on the S3 it *rises*. Run the selftest build — it measures and prints both the direction and a threshold. |
| **GPIO 3 is a strapping pin** | Fine in use, but don't hold a button on it down during power-up. GPIO 2 (pad `D1`) is the drop-in alternative. |
| **The lid had zero clearance in Z** | `LID_CLR` was applied to the lid's length and width but never its thickness, so it was exactly as thick as the groove it slid in. The groove is now `LID_T + LID_CLR`. Worth remembering as a shape: a clearance constant is only as good as the number of places it is actually used. |
| **The detent is sized against the slop, not against feel** | `LID_DETENT` is 0.35 against 0.25mm of slop, so the lid rides up in its own clearance and only 0.10mm comes from bending. With zero slop it needed 0.30mm of bend — which PLA answers by cracking. Kept above the slop rather than equal to it so print tolerance cannot erase the detent. |
| **The lid slides, it does not press on** | It enters from the REAR and stops against the inside of the front end wall, which also registers the camera hole. Its grooves cut **outward into the side walls**, never inward over the cavity: the front pod's cavity is exactly as wide as the XIAO, so any inward lip would stop the board going in. The lid is therefore wider than the opening it covers and cannot be dropped in — endwise is the only way. `LID_DETENT` is a 0.3mm click bump near the entry; set it to 0 for a plain friction slide. |
| **A sealed pod passes every automated check** | The cavity was once cut `out + EPS` deep instead of `out + WALL`, stopping 1.59mm short of the top face and leaving each pod a closed box with no way in. It rendered correctly from outside, exported watertight, and mated with the ring — a sealed void is perfectly manifold. Only a probe down the middle, or looking at a cutaway, finds it. **Verify cavities by probing the interior, not by checking the mesh is valid.** |
| **Never mix ring sizes under one pod** | Each ladder step is 0.6mm thicker, so it stands its rail 0.6mm higher. A pod bridging two different sizes seats on one rail and rocks on the other. Both rings under a pod must be the same size — and with four printed per size, they will be. |
| **Rail squish and slot clearance are one number** | The pod's dovetail slot is cut with `CLEARANCE` of slack, so `DT_SQUISH` on the TPU rail must **exceed** it or the joint is a slip fit and the pod rattles. They were tuned separately once and cancelled out exactly. |
| **The amp is wired flat, not on sockets** | `AMP_HEADERS_FITTED` defaults to false. A jumper socket adds ~10mm to the rear pod, all of it on the axis facing the wearer's head, so the shipped build solders wires straight to the amp pads. A socketed amp will not fit the default pod — render with `-D AMP_HEADERS_FITTED=true` if you need it. |
| **The dovetail needed 0.5mm more, measured** | `DT_SLOT_EXTRA` widens the SLOT only. The printed joint could not be assembled at the designed 0.15mm interference. It is now a 0.35mm clearance fit — and that is fine, because **the taper is what makes the joint captive, not the friction**. A loose slide still cannot lift off the rail. |
| **Pod sizes carry measured corrections** | `FB_EXTRA_*` / `RA_EXTRA_*` are additions made holding the printed parts, kept separate from the component dimensions so it stays clear which is which. `RA_EXTRA_OUT = 15` is the big one: the rear cavity was 8mm deep for a 5mm amp, and the wiring would not fit under the lid. |
| **A GND pin takes more than one wire** | Every ground is the same node. Twist or solder several wires into one joint — that's normal, not a bodge. |

### Trigger options

`USE_PUSH_BUTTON` in `firmware/src/pins.h` selects.

- **Touch pad** — one wire to any scrap of metal, **no ground return**. Best
  when GND pins are spoken for and smallest in the pod. Needs calibration.
  **This is what's built**, so `USE_PUSH_BUTTON` is 0 and the lid is cut for a
  pad. `TRIGGER_IS_BUTTON` in the CAD must match `USE_PUSH_BUTTON` in `pins.h`.
  The pad is an **Australian 20c coin** — 28.52mm across, 2.50mm thick, and
  **11.3g**. The coin is what sizes the camera pod now, not the XIAO: the lid
  must be ≥31mm wide to hold it, which is why `FB_VERT_MIN` is 28 and the pod
  is 34.2mm. `LID_T` is 3.2 rather than 1.6 for the same reason — a 2.5mm
  recess in a 1.6mm plate is a hole, not a pocket.
  **The 11.3g is worth a second look.** The pods were put on opposite temples
  to balance the weight; the coin puts a third of a pod's worth back on one
  side. Copper tape or foil in the same pocket has ample electrode area at
  essentially zero mass, and the pocket takes either.
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

(The reminders mode is a real second configuration in the code, but the demo
runs one profile only — two configurations doubles the setup and doubles what
can break in a three-minute slot.)

The device **surfaces what is printed on the label. It never gives a
verdict.** On a poor image it says it can't see clearly rather than guessing —
which matters more than usual, because the user cannot check its answer.

---

## The user

**Margaret, 78** — synthetic persona, built from the challenge brief and
published research. Macular degeneration; central vision largely gone,
peripheral intact, so she navigates her own home confidently but cannot read
anything she looks directly at. Nine daily medications, kept in a
self-invented order on the windowsill, rechecked by position. Two bottles are
the same size and shape, so she has a rubber band round one of them.

> **The line to say out loud:** *"The baseline isn't nothing. It's a rubber
> band round a pill bottle."* A system she invented, maintains herself, and
> which fails silently the moment someone tidies the windowsill.

Her question for us is *"what happens when it gets it wrong?"* — she cannot
check the answer. That is why the confidence gate exists and why the demo
includes a deliberate failure.

**We did not interview or test with anyone with disability.** The brief calls
for synthetic data and the team as test users. Say that plainly if asked;
it's a limitation, not something to hide, and "we'd validate with real users
next" is the honest next step.

## The pitch

Deck: `Vocalens_Pitch_Deck.pptx`. Nine slides, ~3 minute slot.

### The numbers, with sources

| Claim | Source |
|---|---|
| 60% of people with vision loss struggle to locate or identify their own medication | APH ConnectCenter |
| 64% report missing doses; 33% report inaccurate dosing or spilling | APH ConnectCenter |
| Australia: 400k cataracts · 400k diabetic retinopathy · 200k macular degeneration · 160k glaucoma | AIHW eye health report |

The prevalence slide exists to make the point that glasses and surgery cannot
fully correct many of these conditions — this is not a shrinking problem.

### The Meta Ray-Ban rebuttal

A judge will ask it, so the deck asks it first.

| | |
|---|---|
| **Meta glasses, $800–900** | A phone strapped to your face. Dozens of features an elderly or low-vision user will never touch, or even discover. |
| **VocaLens, <$100** | One job, done reliably. Head-aim replaces screen-aim — no aiming a screen you can't see. |

### The three demo beats, in order

1. **A barcode read** — instant, zero model calls
2. **An open question** — "what does this say?"
3. **A deliberate failure** — it says *"I can't see that clearly"* rather than guessing

Beat 3 is the important one. Rehearse it; don't hope it happens.

### "AI earns its place"

A recognised barcode answers with **zero model calls**. The vision model runs
only for genuinely open-ended questions — a label, a colour, a comparison.
This is a design argument, not a cost saving, and it's worth making explicitly
in a room full of projects that call a model for everything.

### Dignity — four claims the deck makes

- **Who's in control:** only the wearer hears the answer. No escalation, no
  third party notified, ever.
- **Collects only what's needed:** camera and mic capture on trigger only. No
  continuous recording, nothing stored beyond one request.
- **Looks ordinary:** reads as glasses, not medical equipment, at a friend's
  kitchen bench.
- **Not a medical device:** surfaces printed facts, never a safety verdict.

### What we deliberately didn't build

Stating this is a strength. It shows the scope was chosen, not missed.

- Carer notifications or location tracking
- A synced calendar — reminders are wearer-built, on purpose
- Multi-language support — next on the list

### Honest gaps in the deck as it stands

- Slide 4 has a **placeholder** where the product image goes.
- Slide 8's cost breakdown lists a bone-conduction transducer and printed
  frame. The built prototype uses the kit **speaker** and clips to existing
  frames. Slide 5 already concedes the speaker swap — make sure slide 8
  doesn't contradict it.

## Status

| Area | State |
|---|---|
| Server + AI | Works. Testable with `curl` and no hardware at all. |
| Firmware | Builds and flashes. Wake word and mic capture are stubs. |
| Self-test build | Works. Flash `-e selftest` to find which subsystem is broken. |
| CAD | Ring + interlock, validated watertight, mate checked by boolean intersection. |
| Printed and assembled | In progress. |

### Naming

The deck brands it **VocaLens** (capital L). Filenames, CAD and code use
`vocalens` / `Vocalens`. Not worth churning the code over, but **be consistent
in anything a judge sees** — deck, README, the printed pods. The deck spelling
wins.

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
