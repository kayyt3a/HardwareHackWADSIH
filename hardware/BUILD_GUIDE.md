# Vocalens — build guide

Step by step, from printed parts to a working device. This is the single-pod,
zero-purchase build — the committed build for this event, not a stopgap.

## What you need

**From the Freenove kit** (check the parts poster — you have all of these):

| Part | Used for |
|---|---|
| Camera module (stays attached to its FPC ribbon) | The eye of the device |
| Speaker | Speaks the answer |
| Audio Converter & Amplifier | Drives the speaker over I2S |
| Jumper wires (F-F and M-F) | All connections |
| 2×AA battery holder **or** 9V battery cable | Untethered power (optional — USB works too) |

**Your own:** XIAO ESP32S3 Sense, a pair of glasses you don't mind clipping
onto.

**Nothing else.** No purchases for this build. A bone-conduction transducer
and a longer FPC ribbon (for a future two-pod version) are documented in
`hardware/README.md` as pitch material only — not sourced, not needed here.

---

## Step 1 — Measure, before you print anything

Open `cad/vocalens_pod.scad` and update these to your real parts. Callipers
if you have them; a ruler is good enough to start.

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The temple arm of your glasses |
| `CAM_LEN/WID/HGT` | The camera module, still attached to its ribbon |
| `XIAO_LEN/WID/HGT` | The XIAO board (camera stays attached in this build — its height is added automatically, don't include it in `XIAO_HGT`) |
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

## Step 3 — Print the pod

Slice `cad/single_plate.stl` — base, lid, and a spare fit test on one bed,
79 × 67mm total, comfortably inside the Snapmaker U1's 270mm bed.

**Snapmaker U1 settings:**
- Layer height 0.16mm
- 4 perimeters (matches the 1.6mm `WALL`)
- Print as modelled, cavity-up — no supports needed in that orientation
- The lid in the plate is pre-flipped rib-side-up so it sits flat with no
  supports
- PLA is fine; PETG if you want the clip to survive more on/off cycles

## Step 4 — Wire it up

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
the recess in the lid. ESP32 capacitive touch needs no sensor component;
the bare wire and a conductive surface are the whole circuit.

**Power:** USB-C to a laptop or power bank is simplest and most reliable for
a demo. If you want untethered, the 2×AA holder gives ~3V — wire it to the
XIAO's BAT pads. The XIAO expects a LiPo on those pads, so check voltage
before connecting anything.

## Step 5 — Assemble

1. Seat the board in the pod cavity, camera lens aligned with the front
   hole. A dab of hot glue holds it.
2. Stack the amp module on top of the board.
3. Fit the speaker under the grille holes in the lid.
4. Glue the touch-pad metal into its recess in the lid and connect its wire.
5. Route the USB cable (and battery leads, if used) out through the side
   slot.
6. Press the lid on.
7. Clip the pod onto the temple arm, camera end forward.

## Step 6 — Bring it up in this order

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

## Known rough edges — say these plainly in the pitch

- **Front-heavy, 59 × 31 × 30mm.** Everything (board, camera, amp, speaker)
  sits at the front of the temple. It will tug on the glasses. This is the
  direct, honest cost of building entirely from kit parts with no external
  sourcing — the "what we'd build next" slide in `hardware/README.md` names
  exactly what would fix it.
- Pods are square-edged. Rounding the outer shell is a cheap next iteration
  and worth doing before demo night.
- No strain relief where cables exit.
