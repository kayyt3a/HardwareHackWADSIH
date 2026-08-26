# Vocalens — build guide

Step by step, from printed parts to a working device. Two pods, kit parts
only, zero purchases — the committed build for this event.

## What you need

**From the Freenove kit** (check the parts poster — you have all of these):

| Part | Used for |
|---|---|
| Camera module (stays attached to its FPC ribbon) | Front pod — the eye of the device |
| Speaker | Rear pod — speaks the answer |
| Audio Converter & Amplifier | Rear pod — drives the speaker over I2S |
| Jumper wires (M-M, F-F, F-M) | Front-to-rear connection (5 wires) + all local wiring |
| 2×AA battery holder **or** 9V battery cable | Untethered power (optional — USB works too) |

**Your own:** XIAO ESP32S3 Sense, a pair of glasses you don't mind clipping
onto.

**Nothing else.** No purchases for this build. A hidden cable, a
camera-only front pod, and bone conduction are documented in
`hardware/README.md` as pitch material for "what we'd build next" — not
sourced, not needed here.

---

## Step 1 — Measure, before you print anything

Open `cad/vocalens_pod.scad` and update these to your real parts. Callipers
if you have them; a ruler is good enough to start.

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The temple arm of your glasses |
| `CAM_LEN/WID/HGT` | The camera module, still attached to its ribbon |
| `XIAO_LEN/WID/HGT` | The XIAO board (camera stays attached — its height is added automatically, don't double-count it) |
| `SPKR_DIA`, `SPKR_HGT` | The kit speaker |
| `AMP_LEN/WID/HGT` | The audio amplifier module |

## Step 2 — Print the fit test first

```
openscad -o fit_test.stl -D 'part="fit_test"' cad/vocalens_pod.scad
```

Or slice the supplied `cad/fit_test.stl` directly. ~3 minutes to print.

Snap it onto your glasses:

- **Won't go on / splays the arm** → increase `SNAP_GAP`
- **Slides around loosely** → decrease `SNAP_GAP`
- **Rattles in the channel** → your `TEMPLE_*` measurements are too big

Re-print until it grips. Do not skip this — it is the difference between one
wasted evening and four.

## Step 3 — Print both pods

Slice `cad/split_plate.stl` — front pod, rear pod, both lids, and a spare
fit test, 101 × 95mm total, comfortably inside the Snapmaker U1's 270mm bed.

**Snapmaker U1 settings:**
- Layer height 0.16mm
- 4 perimeters (matches the 1.6mm `WALL`)
- Print as modelled, cavity-up — no supports needed in that orientation
- Both lids in the plate are pre-flipped rib-side-up so they sit flat with
  no supports
- PLA is fine; PETG if you want the clip to survive more on/off cycles

## Step 4 — Wire it up

All connections are jumper wires. Nothing here needs soldering except
possibly the speaker leads.

**Front pod → rear pod (I2S, 5 wires, run along the temple arm):**

| Signal | XIAO pin (front pod) | Amp pin (rear pod) |
|---|---|---|
| BCLK / SCK | GPIO 7 (`PIN_I2S_BCLK`) | BCLK |
| LRC / WS | GPIO 8 (`PIN_I2S_LRC`) | LRC |
| DIN | GPIO 9 (`PIN_I2S_DIN`) | DIN |
| Power | 3V3 | VIN |
| Ground | GND | GND |

Use the longer jumper wires from the kit for this run — measure the temple
arm length first and pick wires with a bit of slack, not the shortest ones
you have.

**Speaker → amp (in the rear pod):** the two speaker output terminals.
Polarity doesn't matter for a single speaker.

**Touch pad (in the front pod):** run one jumper wire from **GPIO 3**
(`PIN_TOUCH_PAD`) to a small piece of metal — a coin, a screw head, a scrap
of foil — glued into the recess in the front lid. ESP32 capacitive touch
needs no sensor component; the bare wire and a conductive surface are the
whole circuit.

**Power:** USB-C to a laptop or power bank, into the front pod, is simplest
and most reliable for a demo. If you want untethered, the 2×AA holder gives
~3V — wire it to the XIAO's BAT pads. The XIAO expects a LiPo on those pads,
so check voltage before connecting anything.

## Step 5 — Assemble

**Front pod:**
1. Seat the XIAO (camera attached) in the cavity, lens aligned with the
   front hole. A dab of hot glue holds it.
2. Glue the touch-pad metal into its recess in the lid, connect its wire.
3. Feed the 5 I2S wires out through the rear-face slot.
4. Route the USB cable out through the side slot.
5. Press the lid on.

**Rear pod:**
6. Feed the 5 I2S wires in through the front-face slot, connect to the amp.
7. Seat the amp and speaker side by side in the cavity, speaker under the
   grille holes in the lid.
8. Press the lid on.

**Both:**
9. Clip the front pod onto the temple arm near the hinge, camera forward.
10. Clip the rear pod behind the ear.
11. Run the 5 wires along the top edge of the temple arm between them; a
    dot of removable adhesive at one or two points keeps them tidy and
    stops them snagging.

## Step 6 — Bring it up in this order

Do not try to make everything work at once. Each step below is testable on
its own, and each one you skip is a bug you'll be hunting at 2am.

1. **Camera only, on the bench, pods not yet wired to each other.** Flash,
   hit `/read_label` with the touch pad, confirm the server receives a
   frame. No audio, no mic.
2. **Audio out, still on the bench** with short wires between the two pods
   before committing to the full temple-length run. Confirm the server's
   spoken reply plays through the speaker.
3. **Now extend to the full temple-length wires** and clip both pods on.
   Re-test — a longer run occasionally needs a small pull-up/pull-down
   tweak if signals get noisy, though I2S at this length usually doesn't.
4. **Mic in.** Record a question, confirm the server transcribes it.
5. **Wake word last.** It's the highest-risk piece (see
   `firmware/src/wake_word.h`) and the touch pad already gets you a working
   demo without it.

## Known rough edges — say these plainly in the pitch

- **Jumper wires run exposed** along the temple arm between the pods. Not
  hidden, not strain-relieved. Direct, honest cost of a two-pod split with
  zero external sourcing — a hidden cable or sheath is named as future work
  in `hardware/README.md`.
- Pods are square-edged. Rounding the outer shell is a cheap next iteration
  and worth doing before demo night.
- No strain relief where any cable exits either pod.
