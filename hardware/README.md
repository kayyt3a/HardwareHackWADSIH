# Vocalens — enclosure

**Two pods, kit parts only, zero purchases.** No FPC ribbon, no
bone-conduction transducer — nothing bought. Bone conduction stays a
documented future upgrade (see below); the two-pod split itself is achieved
with the kit's own jumper wires instead.

## What it is

Two 3D-printed pods connected by jumper wires along the temple arm — sitting
**beside** the temple arm, not stacked on top of it (see "How they sit on
the arm" below for why that distinction matters):

- **Front pod** (near the hinge): the XIAO ESP32S3 Sense with its camera
  left attached — no ribbon surgery — plus the touch pad. 48 × 10 × 29mm
  (length along the arm × vertical × outward from the head).
- **Rear pod** (behind the ear): the kit's audio amplifier and speaker.
  57 × 10 × 38mm.

Connected by 5 jumper wires (BCLK, LRC, DIN, 3V3, GND) from the kit's own
stock (65 M-M + 20 F-F + 20 F-M) — I2S is a slow serial protocol, so it
tolerates that run length without the signal-integrity risk a stretched
camera ribbon would carry.

**Honest tradeoff:** the jumper wires run exposed along the outside of the
temple arm for ~10cm. Less tidy than a hidden ribbon, and worth naming
proactively in the pitch: "jumper wires for this prototype, a custom flex
cable in a production version."

Clipping onto an existing frame rather than fabricating one from scratch
avoids the hinge/nose-bridge/lens-fit problem entirely — mounting is the
thing the challenge brief calls out as most often underestimated, and a
frame that already fits a real face solves that for free.

## How they sit on the arm — the vertical dimension is the one that matters

Both pods are deliberately **thin vertically (10mm) and long outward
(29-38mm)**, not the other way around. This isn't cosmetic — it's the
difference between a pod that clears the head and one that doesn't.

A temple arm sits right against the side of the skull. There's almost no
clearance directly above or below it before you hit hair or bone; there's
plenty of clearance straight outward, away from the head. So every
component's **thickness** (a PCB's own profile, a speaker's depth — a few
mm) is what's allowed to add to the pod's vertical extent, and every
component's **footprint** (a 28mm speaker diameter, a 19mm board width) is
what extends outward instead. Get this backwards and the pod piles up on
top of the arm and presses into the wearer's head — which is exactly what
an earlier version of this file did (front pod was 22mm vertical, rear pod
was 31mm, both several times the arm's own ~6mm width).

The front pod's camera also no longer sits stacked on top of the board —
it's positioned beside it along the arm's length instead, using the slack
in its stock ribbon. That trade costs the front pod some length (36mm →
48mm) but is what gets its vertical extent down from 22mm to 10mm — worth
it, since length runs along a part of the head with actual room, and
vertical bulk runs straight into it.

## Files

- `cad/vocalens_pod.scad` — parametric source
- `cad/split_plate.stl` — the two-pod build: both pods, both lids, fit test
- `cad/frontboard_*.stl`, `cad/rearaudio_*.stl` — the same parts separately
- `cad/single_plate.stl` — a one-pod fallback, kept for reference. Still
  bulkier vertically (23mm) than the split build, since it has nowhere to
  lay the board+camera+amp side by side without becoming very long — prefer
  the split build whenever possible.

## Print order

**1. `fit_test.stl` first, always.** Cut from `split_plate.stl` or render
alone:
```
openscad -o fit_test.stl -D 'part="fit_test"' cad/vocalens_pod.scad
```
~3 minutes. Snap it onto your actual glasses.
- Won't go on / splays the arm → increase `SNAP_GAP`, reprint
- Slides around loosely → decrease `SNAP_GAP`, reprint
- Rattles in the channel → your `TEMPLE_THICKNESS`/`TEMPLE_WIDTH` don't
  match your real glasses — measure again

Only proceed once it grips properly.

**2. Then `split_plate.stl`** — both pods, both lids, a spare fit test,
113 × 48mm, comfortably inside the Snapmaker U1's 270 × 270mm bed.

### Slicer settings (Snapmaker U1, 0.4mm nozzle)

- Layer height 0.16mm
- 4 perimeters (`WALL` is 1.6mm, sized for exactly this)
- Print bases cavity-up, as modelled — the temple channel bridges rather
  than needing supports
- Both lids in `split_plate.stl` are pre-flipped rib-side-up so they sit
  flat on the bed with no supports; if slicing a lid alone, flip it yourself
- **Material: print bases in TPU, lids in PETG.** The base is the part
  that flexes every time the pod is clipped on/off — TPU doesn't fatigue or
  crack under repeated flex the way PLA/PETG do, and it's more forgiving of
  small errors in `SNAP_GAP`. The lid doesn't flex; it just needs to hold
  its shape, so keep it rigid (PETG). This needs no CAD changes — it's a
  per-part material choice, not a geometry change. TPU needs its own
  slicer profile (slower speed, less retraction) — test on a spare small
  part first if the U1 doesn't already have one dialled in.
- Use PLA only for the disposable `fit_test.stl` iterations while tuning
  `SNAP_GAP` — fastest to print, and you'll reprint it several times

## Measure before you print

Every dimension in `vocalens_pod.scad` is a **placeholder**. Real numbers,
off your actual parts:

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The glasses you're clipping onto |
| `CAM_LEN/WID/HGT` | The camera module, still attached to its ribbon |
| `XIAO_LEN/WID` | The board's footprint |
| `XIAO_THICK` | The board's own profile (PCB + tallest onboard part, e.g. the USB connector) **excluding** the camera — this is new, and is what lets the camera sit beside the board instead of stacked on it |
| `SPKR_DIA`, `SPKR_HGT` | The kit's round speaker |
| `AMP_LEN/WID/HGT` | The kit's Audio Converter & Amplifier module |

No separate touch sensor needed: ESP32 capacitive touch runs off a bare
GPIO pad. The touch pad is a small metal disc or screw head glued into the
lid's recess and wired back to one pin.

## For the pitch: what we'd build with more time/budget

Say this plainly and proactively — it reads as scoping discipline, not as
an apology, and it directly answers the brief's "what would you do next."

| Upgrade | What it needs | What it buys |
|---|---|---|
| **Camera fully detached from the board** (rather than riding along in the front pod) | A ~10cm FPC ribbon (the camera's kit ribbon is too short to reach the rear pod) | Front pod shrinks to a camera-only footprint, and its length drops back toward ~26mm since the board no longer shares the pod at all |
| **Tidy, hidden cabling** between pods | A short length of thin sheathed cable, or a printed channel | Replaces the exposed jumper wires with something that looks intentional |
| **Bone-conduction audio** | A transducer (not stocked in Perth; not in either kit) | Rear pod's outward extent drops sharply since the speaker's 28mm footprint is replaced by a ~21mm transducer mounted flush against the head rather than sitting inside the cavity; private to the wearer; ears stay open |
| **Wake-word activation** | Firmware only (ESP-SR), no purchase | Hands-free — no tap needed at all |

We deliberately built this prototype from the provided kit with no external
sourcing, so what you're looking at tonight has zero shipping risk and zero
budget beyond what the event gave every team. Pre-rendered reference STLs
for the bone-conduction variant are in `cad/bone_conduction/` if useful for
a visual in the deck — they were not printed for this build.

## Known limitations, stated plainly

- **Jumper wires run exposed** along ~10cm of the temple arm between the
  pods. Not hidden, not strain-relieved. Say this in the pitch rather than
  let a judge notice it first — it's the direct, honest cost of a two-pod
  split with zero external sourcing.
- Both pods extend noticeably outward from the head (29-38mm) in exchange
  for staying thin vertically. That's the deliberate trade this design
  makes — see "How they sit on the arm" above — but it does mean the pods
  are visible in profile from the side, more like a small camera clipped on
  than a flush-fitting accessory.
- Corners are lightly rounded (1mm) but the overall shape is still a
  utilitarian bar, not a finished consumer product.
- The clip grips by spring tension only, from the base material itself
  (TPU is the intended material for exactly this reason — see slicer
  settings above). If a PLA/PETG-printed base still feels loose in
  practice, reprinting the base in TPU is the real fix; there isn't
  meaningful room in the channel's tolerance to add a separate liner
  without resizing it.
- No strain relief where cables exit either pod.
