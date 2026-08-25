# Vocalens — build guide

Step by step, from printed parts to a working device.

## What you need

**From the Freenove kit** (check the parts poster — you have all of these):

| Part | Used for |
|---|---|
| Camera module (FPC ribbon) | Front pod — the eye of the device |
| Speaker | Rear pod — speaks the answer |
| Audio Converter & Amplifier | Drives the speaker over I2S |
| Jumper wires (F-F and M-F) | All connections |
| 2×AA battery holder **or** 9V battery cable | Untethered power (optional — USB works too) |

**Your own:** XIAO ESP32S3 Sense, a pair of glasses you don't mind clipping onto.

**Optional upgrade (~$15–20):** a bone-conduction transducer replacing the
kit speaker, so only the wearer hears the answer. Not needed for a working
prototype — the kit speaker does the job, it's just audible to the room.

## Where to buy in Perth

You probably don't need to buy anything. If you do:

- **Altronics** — 174 Roe St, Northbridge. WA-owned, closest to the city.
  [altronics.com.au](https://www.altronics.com.au/storelocations/)
- **Jaycar** — Osborne Park (83–87 Frobisher Rd), Belmont, Malaga, O'Connor,
  Jandakot. [jaycar.com.au](https://www.jaycar.com.au/store-finder)

Neither reliably stocks bone-conduction transducers — those come from
[Core Electronics](https://core-electronics.com.au) or
[Little Bird](https://littlebirdelectronics.com.au) (east coast, 3–5 days to
Perth, so order early if you want one).

---

## Step 1 — Measure, before you print anything

Open `cad/vocalens_pod.scad` and update these to your real parts. Callipers
if you have them; a ruler is good enough to start.

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The temple arm of your glasses |
| `CAM_LEN/WID/HGT` | The camera module (not the ribbon) |
| `XIAO_LEN/WID/HGT` | The XIAO board, camera detached |
| `SPKR_DIA`, `SPKR_HGT` | The kit speaker |
| `AMP_LEN/WID/HGT` | The audio amplifier module |

## Step 2 — Print the fit test first

```
openscad -o fit_test.stl -D 'part="fit_test"' cad/vocalens_pod.scad
```

Or just slice the supplied `cad/fit_test.stl`. ~3 minutes to print.

Snap it onto your glasses:

- **Won't go on / splays the arm** → increase `SNAP_GAP`
- **Slides around loosely** → decrease `SNAP_GAP`
- **Rattles in the channel** → your `TEMPLE_*` measurements are too big

Re-print until it grips. Do not skip this — it is the difference between one
wasted evening and four.

## Step 3 — Print everything

Slice `cad/plate.stl` — all five parts laid out on one bed, 93 × 84mm total.

**Snapmaker U1 settings:**
- Layer height 0.16mm
- 4 perimeters (matches the 1.6mm `WALL`)
- Print as modelled, cavity-up — no supports needed in that orientation
- PLA is fine; PETG if you want the clip to survive more on/off cycles

## Step 4 — Detach and extend the camera

The camera module unclips from the FPC connector on the XIAO's Sense
expansion board. Lift the small dark retainer bar on the connector, slide
the ribbon out, and the camera comes free.

The kit's ribbon is short (~2cm). You need it to reach from the front pod to
behind the ear (~10cm), so you need a longer FPC cable of the same pitch and
pin count — **this is the one thing you may genuinely need to buy**, and it's
a few dollars. Check the ribbon on your kit camera for pin count before
ordering.

> **If you can't get a longer ribbon in time:** fall back to a single-pod
> design — put everything in one pod at the front of the temple. It's
> chunkier and less elegant, but it works and needs no extra parts. Say so
> in the pitch: "the two-pod split is the design, the single pod is what we
> could build this week."

## Step 5 — Wire it up

All connections are jumper wires. Nothing here needs soldering except
possibly the speaker leads.

**Audio amp → XIAO (I2S):**

| Amp pin | XIAO pin | Note |
|---|---|---|
| BCLK / SCK | GPIO 7 | `PIN_I2S_BCLK` in `firmware/src/pins.h` |
| LRC / WS | GPIO 8 | `PIN_I2S_LRC` |
| DIN | GPIO 9 | `PIN_I2S_DIN` |
| VIN | 3V3 | |
| GND | GND | |

**Speaker → amp:** the two speaker output terminals. Polarity doesn't matter
for a single speaker.

**Touch pad:** run one jumper wire from **GPIO 3** (`PIN_TOUCH_PAD`) to a
small piece of metal — a coin, a screw head, a scrap of foil — glued into
the 6mm recess in `front_lid`. ESP32 capacitive touch needs no sensor
component; the bare wire and a conductive surface are the whole circuit.

**Power:** USB-C to a laptop or power bank is simplest and most reliable for
a demo. If you want untethered, the 2×AA holder gives ~3V — wire it to the
XIAO's BAT pads. Note the XIAO expects a LiPo on those pads, so check
voltage before connecting anything.

## Step 6 — Assemble

1. Seat the camera module in the front pod cavity, lens aligned with the
   7mm hole in the front face. A dab of hot glue holds it.
2. Feed the ribbon out through the slot in the front pod's rear face.
3. Press `front_lid` into the front pod. Glue the touch-pad metal into its
   recess and connect its wire.
4. In the rear pod: XIAO on the bottom, amp stacked on top of it, speaker
   beside them under the grille holes in the lid.
5. Route the USB cable out through the side slot.
6. Press `rear_lid` on.
7. Clip both pods onto the temple arm, camera pod forward near the hinge.
8. Tuck the ribbon along the top edge of the arm; a dot of removable
   adhesive at one or two points keeps it tidy.

## Step 7 — Bring it up in this order

Do not try to make everything work at once. Each step below is testable on
its own, and each one you skip is a bug you'll be hunting at 2am.

1. **Camera only.** Flash, hit `/read_label` with the touch pad, confirm the
   server receives a frame. No audio, no mic.
2. **Audio out.** Confirm the server's spoken reply plays through the
   speaker. Test with a fixed string before involving the model.
3. **Mic in.** Record a question, confirm the server transcribes it.
4. **Wake word last.** It's the highest-risk piece (see
   `firmware/src/wake_word.h`) and the touch pad already gets you a working
   demo without it.

## Known rough edges

- **Rear pod is 59 × 31 × 23mm**, driven by the 28mm kit speaker. A smaller
  speaker or a bone-conduction transducer shrinks it considerably.
- Pods are square-edged. Rounding the outer shells is a cheap next
  iteration and worth doing before demo night.
- No strain relief where the ribbon or USB cable exits.
