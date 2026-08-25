# Vocalens — enclosure, prototype 1

Two clip-on pods that mount to the temple arm of an **existing pair of
glasses**, rather than a printed-from-scratch frame. A full frame (hinges,
nose bridge, lens fit) is a much larger and riskier fabrication job, and
reusing a frame that already fits a real face solves the ergonomics problem
for free — mounting is the thing the challenge brief calls out as most often
underestimated.

## Why two pods, not one

The camera is the only component that *has* to be at the front (it must aim
forward). The XIAO ESP32S3 Sense's camera module detaches from the board and
connects back by a short FPC ribbon, so everything else moves to where bulk
is invisible:

| Pod | Contents | Approx size | Why there |
|---|---|---|---|
| **Front** | Camera module, touch pad | 26 × 14 × 17mm | Must aim forward; kept minimal because it's the part people see |
| **Rear** | XIAO board, battery, buzzer | 62 × 23 × 19mm | Behind the ear — where hearing aids and BTE headphones put their bulk, and hair covers it |

The ribbon runs along the temple arm between them. For a prototype, tuck it
along the top edge with a dab of removable adhesive at one or two points.

## Files

- `cad/vocalens_pod.scad` — parametric source. Everything is driven by the
  measurements at the top of the file.
- `cad/*.stl` — rendered parts, checked manifold/watertight.

## Print these in this order

**1. `fit_test.stl` first — always.** A 12mm slice of just the clip. Three
minutes to print. Snap it onto your actual glasses:

- Won't go on, or splays the arm → reduce `SNAP_GAP`
- Goes on but slides around → increase `SNAP_GAP`
- Rattles / too loose in the channel → reduce `TEMPLE_THICKNESS`/`TEMPLE_WIDTH`
  to match your real measurements

Only move on once it grips properly. This one step is the difference between
one wasted evening and four.

**2. Then the four real parts:** `front_base`, `front_lid`, `rear_base`,
`rear_lid`.

### Suggested slicer settings (Snapmaker U1, 0.4mm nozzle)

- Layer height 0.16mm (these are small parts with small features)
- 4 perimeters — `WALL` is 1.6mm, sized for exactly this
- Orientation: print bases **cavity-up**, as modelled. The temple channel
  then bridges rather than needing supports through the middle of the part.
- Supports: shouldn't be needed in that orientation. If your slicer wants
  them inside the channel, the channel opening is too narrow — check
  `SNAP_GAP`.
- PLA is fine for a prototype. PETG if you want the clip to survive more
  snap-on/off cycles without fatigue.

## MEASURE BEFORE YOU PRINT

The parameters at the top of `vocalens_pod.scad` are **placeholders**, since
the team currently has only the Freenove Ultimate Starter Kit and the XIAO
Sense. These need real numbers:

| Parameter | What to measure |
|---|---|
| `TEMPLE_THICKNESS`, `TEMPLE_WIDTH` | The actual glasses you're clipping onto |
| `CAM_LEN/WID/HGT` | The detached camera module |
| `XIAO_LEN/WID/HGT` | The board **without** the camera module attached |
| `BATT_*` | Sized for a common 3.7V 1S LiPo — not sourced yet |
| `BUZZER_*` | Freenove kit passive buzzer, standing in for the eventual bone-conduction transducer |

## Sourcing

The Freenove kit already contains the speaker, the audio amplifier module,
the camera, and battery holders — so a working prototype needs **no
purchases**. See `BUILD_GUIDE.md` for the full parts mapping and Perth
retailers if you do need something.

Two optional items:
- **A longer FPC ribbon** for the camera, if you want the two-pod split (the
  kit ribbon is too short to reach behind the ear). A few dollars.
- **A bone-conduction transducer** (~$15-20, east-coast suppliers) replacing
  the kit speaker, so only the wearer hears the answer. Nice-to-have for the
  privacy story, not required to work.

No separate touch sensor is needed: ESP32 capacitive touch works off a bare
GPIO pad, so the touch pad is just a small metal disc or screw head glued
into the recess in `front_lid` and wired back to one pin.

## Known limitations of prototype 1

- Pods are square-edged and utilitarian. Rounding/chamfering the outer
  shells is a cheap next iteration and worth doing before demo night — the
  brief judges whether a device looks like something a person would want to
  wear.
- The clip grips by spring tension only. If it proves loose in practice, a
  strip of thin rubber or heat-shrink inside the channel is a faster fix
  than reprinting.
- No strain relief where the ribbon leaves either pod.
