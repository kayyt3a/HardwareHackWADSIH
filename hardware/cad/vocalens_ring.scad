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
RING_IN_VERT  = 7.0;  // Y — undersized vs a typical ~8-9mm arm height
RING_IN_OUT   = 3.2;  // Z — undersized vs a typical ~4-5mm arm thickness
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
DT_SQUISH = 0.15;  // TPU rail printed this much oversize -> interference fit

// ------------------------------------------------------------- component box
// Measure YOUR parts and change these. Everything downstream is derived.
CAM_LEN = 11; CAM_WID = 11; CAM_HGT = 7;
XIAO_LEN = 23; XIAO_WID = 19;
XIAO_THICK = 5;    // board profile WITHOUT the camera (PCB + USB shell)
SPKR_DIA = 28; SPKR_HGT = 6;
AMP_LEN = 22; AMP_WID = 16; AMP_HGT = 5;

// ---------------------------------------------------------------- pod sizing
FB_GAP  = 3;
FB_LEN  = CAM_LEN + FB_GAP + XIAO_LEN + 2 * WALL + 8;
FB_OUT  = max(XIAO_WID, CAM_WID);       // outward (Z) — footprint
FB_VERT = max(XIAO_THICK, CAM_HGT);     // vertical (Y) — thickness

RA_LEN  = AMP_LEN + SPKR_DIA + 2 * WALL + 4;
RA_OUT  = max(AMP_WID, SPKR_DIA);
RA_VERT = max(AMP_HGT, SPKR_HGT);

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

    if (touch_recess)
      translate([length - 12, bw / 2, WALL - 0.6])
        cylinder(h = 0.6 + EPS, d = 9, $fn = 40);

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

  // lids flipped rib-side-up so they sit flat with no supports
  translate([0, fbw + 14 + fbw, WALL + 1.0]) rotate([180, 0, 0])
    frontboard_lid();
  translate([FB_LEN + 8, raw + 14 + raw, WALL + 1.0]) rotate([180, 0, 0])
    rearaudio_lid();
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
