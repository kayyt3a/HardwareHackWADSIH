# Vocalens — enclosure

**Two pods, kit parts only, zero purchases.** No FPC ribbon, no
bone-conduction transducer — nothing bought. Bone conduction stays a
documented future upgrade (see below); the two-pod split itself is achieved
with the kit's own jumper wires instead.

## What it is

Two 3D-printed pods connected by jumper wires along the temple arm:

- **Front pod** (near the hinge): the XIAO ESP32S3 Sense with its camera
  left attached — no ribbon surgery — plus the touch pad. 36 × 22 × 25mm.
- **Rear pod** (behind the ear): the kit's audio amplifier and speaker.
  57 × 31 × 16mm.

Connected by 5 jumper wires (BCLK, LRC, DIN, 3V3, GND) from the kit's own
stock (65 M-M + 20 F-F + 20 F-M) — I2S is a slow serial protocol, so it
tolerates that run length without the signal-integrity risk a stretched
camera ribbon would carry.

This isn't a smaller device than the single-pod version — total plastic and
component volume is similar — but it's a **distributed** one: nothing sits
in one dominating lump near your eye, and the front pod specifically drops
to 36×22×25mm from the single pod's 59×31×30mm.

**Honest tradeoff:** the jumper wires run exposed along the outside of the
temple arm for ~10cm. Less tidy than a hidden ribbon, and worth naming
proactively in the pitch: "jumper wires for this prototype, a custom flex
cable in a production version."

Clipping onto an existing frame rather than fabricating one from scratch
avoids the hinge/nose-bridge/lens-fit problem entirely — mounting is the
thing the challenge brief calls out as most often underestimated, and a
frame that already fits a real face solves that for free.

## Files

- `cad/vocalens_pod.scad` — parametric source
- `cad/split_plate.stl` — the two-pod build: both pods, both lids, fit test
- `cad/frontboard_*.stl`, `cad/rearaudio_*.stl` — the same parts separately
- `cad/single_plate.stl` — the earlier one-pod version, kept for reference

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
101 × 95mm, comfortably inside the Snapmaker U1's 270 × 270mm bed.

### Slicer settings (Snapmaker U1, 0.4mm nozzle)

- Layer height 0.16mm
- 4 perimeters (`WALL` is 1.6mm, sized for exactly this)
- Print bases cavity-up, as modelled — the temple channel bridges rather
  than needing supports
- Both lids in `split_plate.stl` are pre-flipped rib-side-up so they sit
  flat on the bed with no supports; if slicing a lid alone, flip it yourself
- PLA is fine; PETG if the clip needs to survive more on/off cycles

## Measure before you print

Every dimension in `vocalens_pod.scad` is a **placeholder**. Real numbers,
off your actual parts:

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The glasses you're clipping onto |
| `CAM_LEN/WID/HGT` | The camera module, still attached to its ribbon |
| `XIAO_LEN/WID/HGT` | The board (camera stays attached — its height is added automatically, don't double-count it) |
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
| **Camera fully detached from the board** (rather than riding along in the front pod) | A ~10cm FPC ribbon (the camera's kit ribbon is too short to reach the rear pod) | Front pod shrinks further, from 36×22×25mm to a camera-only ~26×14×17mm |
| **Tidy, hidden cabling** between pods | A short length of thin sheathed cable, or a printed channel | Replaces the exposed jumper wires with something that looks intentional |
| **Bone-conduction audio** | A transducer (not stocked in Perth; not in either kit) | Rear pod shrinks from 57×31×16mm to ~31×22×23mm footprint; private to the wearer; ears stay open |
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
- Pods are square-edged. Rounding the shell is cheap to do before demo
  night and worth it — the brief judges whether it looks wearable.
- The clip grips by spring tension only. If loose in practice, a strip of
  thin rubber or heat-shrink inside the channel is a faster fix than
  reprinting.
- No strain relief where cables exit either pod.
