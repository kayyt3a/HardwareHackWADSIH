// ============================================================================
// Vocalens — ring-mount enclosure  (v2, replaces the integrated-clip design)
//
// WHAT CHANGED FROM vocalens_pod.scad
//   v1 baked the temple clip into the pod base, so the pod was sized to one
//   exact temple arm and needed a fit_test / SNAP_GAP tuning loop.
//   v2 splits the two jobs:
//     * temple_ring()  — soft TPU collar. STRETCHES onto the arm: the opening
//       is undersized and the wall is thin, so one ring grips a wide range of
//       arms with no tuning print.
//     * pod_base()     — rigid PETG box. Never touches the glasses. Carries a
//       dovetail SLOT that drops onto the ring's rail.
//
//   Consequence: you print pods once. If a ring doesn't grip, you reprint a
//   ~10 minute ring, not a 3-hour pod with electronics glued into it.
//
// WHICH AXIS IS WHICH, WHEN WORN (unchanged from v1 — read before editing):
//   X (length)  — along the temple arm, front to back.
//   Y (vert)    — the arm's TOP-TO-BOTTOM axis. Growing this pushes the pod
//     UP into the scalp and DOWN toward the ear. KEEP SMALL. Pass a
//     component's THICKNESS here, never its footprint.
//   Z (out)     — straight out, away from the head. Real clearance here.
//     Pass a component's larger footprint here.
//
// INTERLOCK DIRECTION
//   Male dovetail RAIL on the ring (soft TPU), female SLOT in the pod (rigid
//   PETG). Soft-into-hard is deliberate: the TPU rail compresses slightly on
//   assembly, so the joint self-tightens and never rattles, and a small print
//   tolerance error is absorbed by the soft part instead of jamming.
//   The rail is wider at the top than at its neck, so the pod cannot lift
//   off — it only releases by sliding along the arm.
//
// MATERIALS
//   temple_ring  -> TPU  (soft; 15-20% gyroid infill, 2 perimeters)
//   pod bases    -> PETG (rigid)
//   pod lids     -> PETG (rigid)
// ============================================================================

// ---------------------------------------------------------------- tolerances
WALL        = 1.6;   // 4 perimeters at 0.4mm nozzle — don't go below 1.2
CLEARANCE   = 0.3;   // fit tolerance between mating FDM parts
EPS         = 0.01;
EDGE_RADIUS = 1.0;
$fn         = 48;

// ------------------------------------------------------------------ the ring
// STRETCH FIT, like a hair tie — not a loose sleeve.
//
// The opening is deliberately SMALLER than the temple arms it has to fit. A
// thin TPU wall in tension grips far harder, and over a far wider range, than
// a generous opening relying on bumps to take up slack. So the rule here is
// the opposite of the usual one: if it doesn't grip, make the opening
// SMALLER or the wall THINNER — never larger.
//
// Nominal below is undersized against a typical arm (~4-5mm thick, ~8-9mm
// tall). It stretches up comfortably; a very slim arm is the case that goes
// loose, which is the safer way round to be wrong.
RING_LEN      = 14;   // X — how much of the arm the ring covers
RING_IN_VERT  = 5.0;  // Y — undersized vs a typical ~8-9mm arm height
RING_IN_OUT   = 2.2;  // Z — undersized vs a typical ~4-5mm arm thickness
RING_WALL     = 1.2;  // thin on purpose: 3 perimeters, stretches easily.
                      // Thicker walls fight you on every fit.


// The rail must NOT stretch with the rest of the ring, or the pod joint
// changes size depending on whose glasses it's on. So the wall directly under
// the rail is locally thickened: the thin side walls do all the stretching
// while the rail footprint stays dimensionally stable.
RAIL_BOSS_T   = 1.4;  // extra wall thickness under the rail only

// -------------------------------------------------------------- the dovetail
// Trapezoid, WIDER AT THE TOP so the pod can't be pulled straight off.
DT_NECK   = 5.0;   // width at the root (narrow)
DT_HEAD   = 8.0;   // width at the top (wide)
DT_HEIGHT = 4.0;
// The pod's slot is cut with CLEARANCE (0.3) of slack, so the rail must be
// grown by MORE than that or the joint is a slip fit and the pod rattles —
// the numbers must be read together, not tuned separately.
//   net interference per face = DT_SQUISH - CLEARANCE = 0.15mm
// which TPU takes up by compressing. Raise it if the pod is still loose;
// lower it if the pod will not slide on by hand.
DT_SQUISH = 0.45;

// ------------------------------------------------------------- component box
// MEASURE YOUR OWN PARTS AND CHANGE THESE BEFORE PRINTING.
//
// These are nominal figures, not measurements of the parts in your kit, and
// every pod dimension is derived from them — so an error here is an error in
// the print. SPKR_DIA is the one to check first: it alone sets the rear pod's
// outward bulk (28mm of a 31mm pod), so if your speaker is smaller than 28mm
// the whole rear pod shrinks with it for free.
CAM_LEN = 11; CAM_WID = 11; CAM_HGT = 7;
XIAO_LEN = 23; XIAO_WID = 19;
XIAO_THICK = 5;    // board profile WITHOUT the camera (PCB + USB shell)

// HEADERS_FITTED — set true if you soldered the 2x7 pin headers onto the board.
//
// This matters more than it looks. Headers plus a pushed-on jumper socket add
// roughly 10mm to the board's profile, and that profile drives the pod's
// VERTICAL extent — the axis that runs into the wearer's scalp and ear, where
// there is almost no clearance. Bare board gives a 10.2mm pod; with headers it
// is about 19mm, which is close to the bulk the whole two-pod split was meant
// to avoid.
//
// So: headers are excellent for bench testing (everything just plugs in, no
// iron, and you can unplug to debug). For the pod that goes on a face, either
// print the taller variant and accept the bulk, or remove the headers and
// solder wires flat to the pads.
HEADERS_FITTED  = false;
HEADER_STACK    = 16;   // board + header plastic + mated jumper socket
XIAO_PROFILE    = HEADERS_FITTED ? HEADER_STACK : XIAO_THICK;


// WIRE_ROOM — headroom above the tallest component for wire to lie in and,
// more importantly, to TURN in.
//
// A jumper socket pushed onto a header leaves along the pin axis, which is the
// vertical (Y) axis here, and then has to turn 90 degrees to run along the pod.
// With no allowance the wire is forced flat against the lid the moment it
// leaves the socket, and the bend loads the solder joint rather than the wire.
// Stranded jumper wire bends tightly without harm; the joint it is pulling on
// does not.
//
// Bends of any size happen in the X-Z plane, where there is 19mm (front) and
// 28mm (rear) to work in, so this only has to cover the initial turn.
WIRE_ROOM = 2;
SPKR_DIA = 28; SPKR_HGT = 6;
AMP_LEN = 22; AMP_WID = 16; AMP_HGT = 5;

// MUST COME AFTER AMP_HGT ABOVE. At top level OpenSCAD resolves in file order,
// so a forward reference here silently becomes undef, RA_VERT becomes undef,
// and the rear pod exports as a stub with no body and no error.
//
// The amp gets its own flag because whether IT has headers is independent of
// whether the XIAO does — you might plug into the XIAO and solder wires flat to
// the amp, or the reverse. It follows HEADERS_FITTED by default.
AMP_HEADERS_FITTED = HEADERS_FITTED;
AMP_PROFILE        = AMP_HEADERS_FITTED ? HEADER_STACK : AMP_HGT;

// ---------------------------------------------------------------- pod sizing
// The two trailing constants below are SLACK — room for wire bends and for
// components sitting a little proud of their nominal size. They were set
// generously while the layout was still moving. Now that it is fixed they are
// cut to the minimum that still lets a wire turn a corner: every millimetre
// here is length hanging off the side of someone's face.
FB_GAP  = 1.5;
FB_LEN  = CAM_LEN + FB_GAP + XIAO_LEN + 2 * WALL + 3;
// BOARDS STAND ON EDGE. Their broad face is parallel to the side of the head,
// not lying flat like a shelf.
//
// This reverses an earlier rule that said to keep the VERTICAL axis small and
// pass component thickness to it. That rule was protecting against the pod
// pressing into the scalp — but the pod cannot press into anything. The ring
// sits between it and the arm, so the pod body starts about 12mm outboard and
// is centred on the arm: growing it vertically happens in free air.
//
// The axis that is actually expensive is OUTWARD, because that is the one a
// person sees. Lying the 19mm board flat projected the pod 34mm off the arm —
// a box on the side of the head. Standing it on edge puts 19mm on the vertical
// axis, where it reads as a thick glasses arm and follows the line of the
// frame, and leaves only board thickness sticking out.
FB_VERT = max(XIAO_WID, CAM_WID);                  // vertical (Y) — footprint
FB_OUT  = max(XIAO_PROFILE, CAM_HGT) + WIRE_ROOM;  // outward (Z) — thickness

RA_LEN  = AMP_LEN + SPKR_DIA + 2 * WALL + 2;
// Same for the rear pod, and it matters more here: the speaker's 28mm was the
// single biggest number in the build and it was pointed straight out sideways.
// On edge it runs vertically, behind the ear, where the ear itself hides it —
// which is exactly where a behind-the-ear hearing aid puts the same bulk.
RA_VERT = max(AMP_WID, SPKR_DIA);
RA_OUT  = max(AMP_PROFILE, SPKR_HGT) + WIRE_ROOM;

// ============================================================================
// helpers
// ============================================================================

module rounded_prism(l, w, h, r) {
  linear_extrude(height = h)
    offset(r = r) offset(delta = -r) square([l, w]);
}

// Dovetail cross-section, extruded along X.
// grow: positive inflates every face (used to cut the pod's slot with
// clearance, and to print the TPU rail slightly oversize).
// NOTE ON THE -h BELOW — do not "tidy" it to +h.
// rotate([0,90,0]) maps a point (x,y,z) to (z,y,-x). That is what turns the
// extrusion axis into X (the length runs along the arm), but it also flips the
// profile's own height axis. Writing the profile height as +h therefore buries
// the rail INSIDE the ring body instead of standing it proud, and the joint
// silently does not exist. Negating it puts the rail on +Z where it belongs.
module dovetail(length, grow = 0) {
  neck = DT_NECK + 2 * grow;
  head = DT_HEAD + 2 * grow;
  h    = DT_HEIGHT + grow;
  rotate([0, 90, 0])
    linear_extrude(height = length)
      polygon([[0, -neck / 2], [0, neck / 2], [-h, head / 2], [-h, -head / 2]]);
}

// ============================================================================
// TPU ring
// ============================================================================

module temple_ring() {
  ow = RING_IN_VERT + 2 * RING_WALL;   // outer, Y
  oh = RING_IN_OUT  + 2 * RING_WALL;   // outer, Z
  boss_w = DT_HEAD + 2;                // footprint of the stiffened region

  difference() {
    union() {
      // thin stretchy body
      rounded_prism(RING_LEN, ow, oh, 1.0);

      // local stiffening under the rail, so the joint keeps its dimensions
      // while the thin side walls take all the stretch
      translate([0, ow / 2 - boss_w / 2, oh - EPS])
        rounded_prism(RING_LEN, boss_w, RAIL_BOSS_T + EPS, 0.6);

      // the rail itself, printed slightly oversize for an interference fit
      translate([0, ow / 2, oh + RAIL_BOSS_T - EPS])
        dovetail(RING_LEN, DT_SQUISH);
    }

    // the arm passes through — undersized, the TPU stretches onto it
    translate([-EPS, RING_WALL, RING_WALL])
      cube([RING_LEN + 2 * EPS, RING_IN_VERT, RING_IN_OUT]);
  }
}

// ============================================================================
// pod base — rigid box with the dovetail slot underneath
// ============================================================================

module pod_base(length, out, vert, cable_slot_front = true) {
  bw = vert + 2 * WALL;                  // Y outer
  bh = out + 2 * WALL;                   // Z outer
  slot_pad = DT_HEIGHT + WALL;           // extra Z for the slot boss

  difference() {
    union() {
      rounded_prism(length, bw, bh, EDGE_RADIUS);
      // boss on the underside carrying the dovetail slot
      translate([0, bw / 2 - (DT_HEAD + 2 * WALL) / 2, -slot_pad])
        rounded_prism(length, DT_HEAD + 2 * WALL, slot_pad + EPS, 0.8);
    }

    // component cavity, open at the top (+Z)
    translate([WALL, WALL, WALL])
      cube([length - 2 * WALL, vert, out + EPS]);

    // dovetail slot, cut all the way through in X so it slides on
    translate([-EPS, bw / 2, -slot_pad])
      dovetail(length + 2 * EPS, CLEARANCE);

    // cable exit
    if (cable_slot_front)
      translate([-EPS, bw / 2 - 3, WALL + out / 2 - 2])
        cube([WALL + 2 * EPS, 6, 4]);
    // cable entry at the other end
    translate([length - WALL - EPS, bw / 2 - 3, WALL + out / 2 - 2])
      cube([WALL + 2 * EPS, 6, 4]);
  }
}

// ============================================================================
// lid
// ============================================================================

// TRIGGER_IS_BUTTON must match USE_PUSH_BUTTON in firmware/src/pins.h.
// A touch pad needs a shallow dish to glue a metal disc into; a button needs a
// hole for its plunger to poke through. They are not interchangeable, so the
// lid has to know which one is fitted.
TRIGGER_IS_BUTTON = false;
BUTTON_PLUNGER_D  = 4.2;   // clearance hole for the plunger, not the body

// ------------------------------------------------------------ the touch pad
// WHY THIS IS A STADIUM AND NOT A CIRCLE.
//
// The lid's outer face is only (vert + 2*WALL) wide — 10.2mm on the front pod.
// That is the Y axis, the one that runs into the scalp and the ear, and the
// entire two-pod split exists to keep it small. So widening the pod to take a
// real ~20mm coin would undo the thing the design is for.
//
// Capacitance goes with AREA, not diameter, so the pad is specified as a
// stadium rather than a disc and grows along whichever axis has room.
//
// It used to be 9mm wide because the lid face was only 10.2mm across. Standing
// the boards on edge widened that face to 22.2mm, so the pad is now 18 x 20mm
// — four times the area, and wide enough to take a real coin if you have one
// glued up already. It is still a stadium, not a circle, because nothing is
// gained by shrinking it back to fit a round outline.
//
// Cut into the OUTSIDE of the lid, so the disc drops in flush and there is no
// proud edge to catch on hair. PAD_WIRE_D goes right through into the cavity:
// solder the trigger wire to the BACK of the pad before gluing it in, so no
// solder joint is visible and nothing conductive is exposed to a fingertip.
PAD_W      = 18.0;  // across the lid (Y). Clamped to (vert + 2*WALL) - 2 in code.
PAD_L      = 20.0;  // along the arm (X). Free to grow — this is the cheap axis.
PAD_DEPTH  = 0.8;   // set to your disc/foil thickness so it finishes flush
PAD_WIRE_D = 2.2;   // pass-through for the trigger wire

module pod_lid(length, out, vert, camera_hole = false, touch_recess = false,
               grille = false) {
  bw = vert + 2 * WALL;
  lid_l = length - 2 * WALL - 2 * CLEARANCE;
  lid_w = bw - 2 * WALL - 2 * CLEARANCE;

  difference() {
    union() {
      rounded_prism(length, bw, WALL, EDGE_RADIUS);
      // friction rib that drops into the cavity
      translate([WALL + CLEARANCE, WALL + CLEARANCE, WALL - EPS])
        rounded_prism(lid_l, lid_w, 1.0, 0.6);
    }

    // ports are cut through the SOLID lid, never into open cavity air
    if (camera_hole)
      translate([WALL + 6, bw / 2, -EPS])
        cylinder(h = WALL + 1.0 + 2 * EPS, d = 7, $fn = 40);

    if (touch_recess) {
      if (TRIGGER_IS_BUTTON) {
        // Through-hole: the switch body sits under the lid and only its
        // plunger comes through, so the lid still holds the switch down.
        translate([length - 12, bw / 2, -EPS])
          cylinder(h = WALL + 1.0 + 2 * EPS, d = BUTTON_PLUNGER_D, $fn = 32);
        // Shallow countersink so a fingertip can find the button by feel —
        // the wearer cannot see it.
        translate([length - 12, bw / 2, WALL - 0.5])
          cylinder(h = 0.5 + EPS, d = BUTTON_PLUNGER_D + 3, $fn = 32);
      } else {
        // Stadium recess for the glued-in pad. Two cylinders plus the bar
        // between them, so the ends stay round and there is no sharp corner
        // for the disc to have to match.
        pad_w = min(PAD_W, bw - 2);          // never breach the side walls
        cx    = length - PAD_L / 2 - 4;      // sits at the rear, clear of the lens
        span  = PAD_L - pad_w;               // centre-to-centre of the end radii

        translate([cx, bw / 2, WALL - PAD_DEPTH]) {
          hull() {
            for (dx = [-span / 2, span / 2])
              translate([dx, 0, 0])
                cylinder(h = PAD_DEPTH + EPS, d = pad_w, $fn = 40);
          }
        }

        // Wire pass-through into the cavity. Solder to the pad's underside.
        // WALL + 1.0 because the friction rib sits on top of the lid plate
        // here — a hole only WALL deep stops inside the rib and never breaks
        // through into the cavity, so the wire has nowhere to go.
        translate([cx, bw / 2, -EPS])
          cylinder(h = WALL + 1.0 + 2 * EPS, d = PAD_WIRE_D, $fn = 24);
      }
    }

    if (grille)
      for (a = [0 : 60 : 359], r = [2.6, 5.2])
        translate([length - 16 + r * cos(a), bw / 2 + r * sin(a), -EPS])
          cylinder(h = WALL + 1.0 + 2 * EPS, d = 1.8, $fn = 16);
  }
}

// ============================================================================
// parts
// ============================================================================

module frontboard_base() { pod_base(FB_LEN, FB_OUT, FB_VERT); }
module frontboard_lid()  { pod_lid(FB_LEN, FB_OUT, FB_VERT,
                                   camera_hole = true, touch_recess = true); }
module rearaudio_base()  { pod_base(RA_LEN, RA_OUT, RA_VERT); }
module rearaudio_lid()   { pod_lid(RA_LEN, RA_OUT, RA_VERT, grille = true); }

// Four rings: two per pod (front and back of each) so each pod is held at two
// points and can't rock. Printing four also gives you spares.
module ring_set() {
  for (i = [0 : 3])
    translate([i * (RING_LEN + 4), 0, 0]) temple_ring();
}

// ============================================================================
// print plates
// ============================================================================

// Everything rigid, one plate, PETG.
module petg_plate() {
  fbw = FB_VERT + 2 * WALL;
  raw = RA_VERT + 2 * WALL;

  translate([0, 0, DT_HEIGHT + WALL]) frontboard_base();
  translate([FB_LEN + 8, 0, DT_HEIGHT + WALL]) rearaudio_base();

  // Lids sit rib-side-UP, flat face on the bed, so nothing needs support.
  //
  // Do not add a rotate([180,0,0]) here. That turns the rib downward, which
  // lifts the lid plate 1mm off the bed and leaves its whole perimeter
  // overhanging the rib by ~1.9mm with nothing under it — the edges droop.
  // Rib-up also puts the pad recess and the camera hole on the top surface,
  // where they print cleanly, and gives the pad a flat bonding face.
  translate([0, fbw + 14 + fbw, 0]) frontboard_lid();
  translate([FB_LEN + 8, raw + 14 + raw, 0]) rearaudio_lid();
}

// Everything soft, one plate, TPU.
module tpu_plate() { ring_set(); }

// ============================================================================
// render selector:  openscad -o out.stl -D 'part="frontboard_base"' this.scad
// ============================================================================
part = "petg_plate";

if      (part == "temple_ring")     temple_ring();
else if (part == "ring_set")        ring_set();
else if (part == "frontboard_base") frontboard_base();
else if (part == "frontboard_lid")  frontboard_lid();
else if (part == "rearaudio_base")  rearaudio_base();
else if (part == "rearaudio_lid")   rearaudio_lid();
else if (part == "tpu_plate")       tpu_plate();
// "none" renders nothing. Needed so another file can `include` this one for
// its modules and constants without the selector below also emitting a plate
// into that file's output.
else if (part == "none")            ;
else                                petg_plate();
