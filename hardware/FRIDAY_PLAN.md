# Friday prototype — two-day plan

**Goal:** something you can put on your face, tap, and hear it read a label.
Nothing more. Wake word, bone conduction and the two-pod split are all
*after* Friday.

**Why single pod:** the two-pod design needs a ~10cm FPC ribbon to reach
behind the ear. You don't have one and can't get one in two days. The single
pod uses the camera's own kit ribbon and needs zero purchases.

**Files:** `cad/single_plate.stl` — base, lid, fit test. That's the whole
Friday print.

**Honest expectations.** The pod is 59 × 31 × 30mm and front-heavy; it will
tug the glasses down your nose. That is fine for Friday — it proves the
concept works end to end. Slimming it is what the remaining three weeks and
the ordered parts are for.

---

## Split the work — 4 people, 2 tracks in parallel

Do NOT serialise this. Tracks A and B don't touch each other until Thursday
evening.

| Track | People | Job |
|---|---|---|
| **A — Electronics** | 2 | Get camera → server → speech working on the bench |
| **B — Enclosure** | 2 | Measure, print, test-fit |

---

## WEDNESDAY

### Track A — electronics (bench only, no enclosure)

1. **Flash the XIAO, confirm the camera works.** Use any stock ESP32 camera
   example first. If you don't get an image, stop and fix that — nothing
   downstream matters.
   - PSRAM must be set to **OPI PSRAM** in board config or camera init fails.
2. **Stand up the server.** `cd server && pip install -r requirements.txt`,
   fill in `.env`, `uvicorn main:app --host 0.0.0.0 --port 8000`.
   - `pyzbar` needs the system `zbar` library — `apt install libzbar0` /
     `brew install zbar`. Do this now, not Thursday night.
   - Test it with no hardware at all: POST a photo of a label from your
     laptop to `/read_label` with curl. Confirm you get audio back. **This
     de-risks the whole AI half before hardware is involved.**
3. **Wire the amp + speaker** (jumper wires, no soldering unless the speaker
   leads need it):

   | Amp | XIAO | |
   |---|---|---|
   | BCLK/SCK | GPIO 7 | |
   | LRC/WS | GPIO 8 | |
   | DIN | GPIO 9 | |
   | VIN | 3V3 | |
   | GND | GND | |

   Play any fixed sound from the XIAO. Don't involve the server yet.
4. **Join them up.** Tap-to-capture → server → speech out of the speaker.
   For the touch pad, a jumper wire from **GPIO 3** to a coin or screw head.

**End of Wednesday, Track A:** a breadboard rat's nest that takes a photo
when you touch a wire and speaks the answer. Ugly. Working.

### Track B — enclosure

1. **Measure everything** with callipers (ruler is OK):
   - Temple arm thickness and width of the glasses you're using
   - The XIAO with camera attached, and the amp module, and the speaker
2. **Update those numbers** at the top of `cad/vocalens_pod.scad`.
3. **Print `fit_test` only.** ~3 minutes. Snap it on the glasses.
   - Won't go on / splays the arm → increase `SNAP_GAP`, reprint
   - Slides around → decrease `SNAP_GAP`, reprint
   - Expect 2-3 iterations. This is normal and it is cheap.
4. Once the clip grips: re-render and print `single_plate.stl`.
   ```
   openscad -o single_plate.stl -D 'part="single_plate"' cad/vocalens_pod.scad
   ```

**End of Wednesday, Track B:** a clip that grips your glasses properly, and
a pod printing overnight.

---

## THURSDAY

### Track B (morning)

5. **Dry-fit the electronics into the printed pod** — no glue yet. Does the
   board go in? Does the camera line up with the lens hole? Does the lid
   close?
   - Something doesn't fit → adjust that parameter, reprint that one part.
     You have all day. This is why you dry-fit before gluing.

### Track A (morning) — hardening, not new features

6. **Run the demo ten times in a row.** Count failures. You're looking for:
   - WiFi dropping or reconnecting slowly
   - Touch pad false-triggering or missing taps (tune `TOUCH_THRESHOLD`)
   - Server timeouts
7. **Fix whatever failed.** Do not add features today.

### Both tracks (afternoon)

8. **Assemble for real.**
   - Board in the pod, camera lens aligned with the hole, dab of hot glue
   - Amp stacked on the board, speaker under the grille holes
   - Touch-pad metal glued into the lid recess, wire connected
   - USB cable out through the side slot
   - Press the lid on, clip the pod to the temple arm
9. **Wear it. Test it. Ten more times.**

---

## FRIDAY

10. **Morning: demo rehearsal, not building.** Run the three demo beats:
    - a barcode read (fast, no model call)
    - an open question ("what does this say?")
    - a deliberate bad angle → it says it can't see clearly
11. **Take photos and video of it working.** Do this while it works. If
    something breaks Friday afternoon you still have evidence.
12. **Write down what broke this week and what you'd do next.** That's your
    "what's next / what we didn't build" pitch slide, and it's much easier to
    write now than three weeks from now.

---

## If you fall behind — cut in this order

1. **Cut the spoken question first.** Tap-to-capture with a fixed "what does
   this say?" is a complete demo. `/read_label` already does exactly this and
   needs no mic work at all.
2. **Cut on-device audio second.** Play the server's reply from the laptop
   speakers. Say so plainly in the pitch — judges accept scoping honesty.
3. **Cut the enclosure last.** Electronics gaffer-taped to glasses still
   demonstrates the idea. A beautiful empty box does not.

**Never cut:** the confidence gate that makes it say "I can't see that
clearly." That behaviour is worth more to the judges than any feature —
it is a specific thing the brief says it scores.

---

## After Friday (the remaining 3 weeks)

- Order the long FPC ribbon and bone-conduction transducer **this week**
- Two-pod split → front pod 26 × 14 × 17mm, rear 31 × 22 × 23mm
- Wake word (ESP-SR) — highest risk, keep the touch pad as backup regardless
- Round the enclosure edges; the brief judges whether it looks wearable
- Battery, so it isn't USB-tethered
