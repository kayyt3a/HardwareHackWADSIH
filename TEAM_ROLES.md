# FourSight — who owns what

Four people, four owned areas. The point of the split is that **nobody is
ever blocked waiting on someone else**, and every part of the product has
exactly one person whose name is on it.

Assign the letters to real names at your first standup and put them at the
top of this file.

| | Role | Owns | The thing they must not let fail |
|---|---|---|---|
| **A** | Firmware | The device | The board captures and speaks on demand |
| **B** | Server / AI | The intelligence | The answer is right, or honestly says it isn't |
| **C** | Hardware | The physical thing | It fits on a face and stays there |
| **D** | Demo & pitch | The story | It works live, and the pitch answers the brief |

---

## A — Firmware owner

**Owns:** `firmware/`, the XIAO, everything that runs on the device.

- **Week 1:** camera capture working, tap-to-trigger on GPIO 3, I2S audio out
  through the amp and speaker. Photo posts to B's server and the reply plays.
- **Week 2:** mic recording on long-press, spoken question uploaded alongside
  the photo. Tune `TOUCH_THRESHOLD` so it doesn't false-trigger.
- **Week 3:** wake word (ESP-SR). **This is the highest-risk item in the whole
  project.** Timebox it. If it isn't working by end of week 3, ship the touch
  pad and say so in the pitch — that is a perfectly good outcome.
- **Week 4:** battery power instead of USB tether. Reliability passes.

**Done means:** trigger → photo + audio uploaded → reply plays, ten times in
a row without a failure.

**Watch out for:** PSRAM must be set to OPI PSRAM or the camera won't init.
Don't start on the wake word until everything else is solid.

---

## B — Server / AI owner

**Owns:** `server/`, the vision prompt, the API keys and cost.

- **Week 1:** server running, `/read_label` answering correctly from photos
  curl'd off a laptop. **Do this before A has working hardware** — it de-risks
  the entire AI half independently.
- **Week 2:** `/ask` with Whisper transcription; barcode fast-path verified
  against real products; tune the confidence threshold.
- **Week 3:** profile modes (dosage facts / reminders). Test the prompt
  refuses to give medical advice — a judge will probe this.
- **Week 4:** latency tuning, graceful failure when WiFi or the API drops.

**Done means:** given a bad photo it says "I can't see that clearly" instead
of guessing. Given a good one it answers in under ~5 seconds.

**Watch out for:** `pyzbar` needs the system `zbar` library installed. Keep
an eye on API credit burn from day one.

---

## C — Hardware owner

**Owns:** `hardware/`, the CAD, the printer, assembly, how it looks.

- **Week 1:** measure everything, update the `.scad` parameters, iterate
  `fit_test` until the clip grips properly, print and dry-fit the single pod.
- **Week 2:** switch to the two-pod design once the long FPC ribbon arrives.
  Cable routing and strain relief.
- **Week 3:** make it look like something a person would wear — round the
  edges, tidy the seams, sensible filament colour. **The brief explicitly
  judges this.** Also fit the bone-conduction transducer when it lands.
- **Week 4:** final assembly, plus a spare printed set in case something
  cracks on demo day.

**Done means:** someone can wear it for ten minutes without it sliding off or
annoying them.

**Watch out for:** book printer slots early — the brief says printing is the
most common cause of a demo-night scramble. **Order the FPC ribbon and
transducer in week 1**, not when you need them.

---

## D — Demo & pitch owner

**Owns:** the deck, the persona, demo-night execution, and — most
importantly — **integration testing**.

This is not the "non-technical" job. D is the only person testing the whole
system as a user would, which is the only test that predicts demo night.

- **Week 1:** build out the Margaret persona properly. Talk to mentors about
  how people with low vision actually organise a pantry. Collect the props
  you'll demo with (medication boxes, similar-looking bottles, a barcoded
  item, something handwritten).
- **Week 2:** start end-to-end testing whatever A, B and C have. Log every
  failure and hand it to whoever owns it. Draft the deck.
- **Week 3:** rehearse the three demo beats — barcode read, open question,
  deliberate failure. Time the pitch. Prepare answers to the brief's dignity
  questions: who's in control, what does it collect, what happens when it's
  wrong, what does it cost.
- **Week 4:** rehearse daily. Own the demo-night run sheet and the backup
  plan.

**Done means:** the demo runs three times in a row without surprises, and the
pitch is under time.

**Watch out for:** don't let this role drift into "just does slides." The
integration testing is the valuable half.

---

## Where the tracks meet

Everything else runs in parallel; these are the only hard dependencies.

| When | Handoff |
|---|---|
| **End week 1** | A's device talks to B's server. First real end-to-end. |
| **Mid week 2** | C's printed pod holds A's electronics. Dry-fit before gluing. |
| **End week 2** | D starts testing the assembled system daily. |
| **End week 3** | Feature freeze. Nothing new after this — only fixes. |
| **Week 4** | Everyone rehearses. |

**Feature freeze at end of week 3 is the most important line in this
document.** Teams lose hackathons by adding a feature on the last day and
breaking the thing that worked.

---

## Cross-training (do this, it's cheap insurance)

By end of week 2, at least two people should be able to:
- Flash the firmware
- Start the server and check its logs
- Slice and start a print

One person getting sick in week 4 should not end your project.

---

## Standups

Ten minutes, same time daily. Three questions each:
1. What's working now that wasn't yesterday?
2. What's blocking you?
3. What do you need from someone else in this room?

If an answer to (3) exists, resolve it in the room. Don't leave it for later.
