# Vocalens — enclosure

**One pod, kit parts only, zero purchases.** This is the committed build for
this event — not a stopgap. Everything below describes what's actually
being built; the two-pod split and bone conduction are documented separately
as future upgrades for the pitch, not part of this build.

## What it is

A single 3D-printed pod that clips onto the temple arm of an **existing
pair of glasses**, holding the XIAO ESP32S3 Sense (camera still attached),
the kit's audio amplifier module, and the kit's speaker. Mounted at the
front of the temple so the camera aims forward.

Clipping onto an existing frame rather than fabricating one from scratch
avoids the hinge/nose-bridge/lens-fit problem entirely — mounting is the
thing the challenge brief calls out as most often underestimated, and a
frame that already fits a real face solves that for free.

**Size:** 59 × 31 × 30mm. Front-heavy — it will tug on the glasses a bit.
That's an honest, stated limitation of building entirely from kit parts, not
something to hide: see "For the pitch" below.

## Files

- `cad/vocalens_pod.scad` — parametric source
- `cad/single_plate.stl` — the whole build: base, lid, fit test, one bed
- `cad/single_base.stl`, `cad/single_lid.stl` — the same two parts separately

## Print order

**1. `fit_test.stl` first, always.** Cut from `single_plate.stl` or render
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

**2. Then `single_plate.stl`** — base + lid + another fit test, 79 × 67mm,
comfortably inside the Snapmaker U1's 270 × 270mm bed.

### Slicer settings (Snapmaker U1, 0.4mm nozzle)

- Layer height 0.16mm
- 4 perimeters (`WALL` is 1.6mm, sized for exactly this)
- Print bases cavity-up, as modelled — the temple channel bridges rather
  than needing supports
- The lid in `single_plate.stl` is pre-flipped rib-side-up so it sits flat
  on the bed with no supports; if slicing the lid alone, flip it yourself
- PLA is fine; PETG if the clip needs to survive more on/off cycles

## Measure before you print

Every dimension in `vocalens_pod.scad` is a **placeholder**. Real numbers,
off your actual parts:

| Parameter | Measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The glasses you're clipping onto |
| `CAM_LEN/WID/HGT` | The camera module, still attached to its ribbon |
| `XIAO_LEN/WID/HGT` | The board (camera stays attached in this build — `SP_STACK_H` adds `CAM_HGT` automatically, don't double-count it in `XIAO_HGT`) |
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
| **Two-pod split** — camera up front, board/amp/speaker behind the ear | A ~10cm FPC ribbon (the camera's kit ribbon is too short) | Front pod shrinks to 26×14×17mm; bulk moves to where hair hides it |
| **Bone-conduction audio** | A transducer (not stocked in Perth; not in either kit) | Rear pod shrinks from 59×31×23mm to ~31×22×23mm; private to the wearer; ears stay open |
| **Wake-word activation** | Firmware only (ESP-SR), no purchase | Hands-free — no tap needed at all |

We deliberately built this prototype from the provided kit with no external
sourcing, so what you're looking at tonight has zero shipping risk and zero
budget beyond what the event gave every team. Pre-rendered reference STLs
for the bone-conduction variant are in `cad/bone_conduction/` if useful for
a visual in the deck — they were not printed for this build.

## Known limitations, stated plainly

- **Front-heavy.** The kit speaker (28mm) and board sit up front with the
  camera. Say this in the pitch rather than let a judge discover it.
- Pods are square-edged. Rounding the shell is cheap to do before demo
  night and worth it — the brief judges whether it looks wearable.
- The clip grips by spring tension only. If loose in practice, a strip of
  thin rubber or heat-shrink inside the channel is a faster fix than
  reprinting.
- No strain relief where cables exit.
