// Vocalens temple-clip pods — first mechanical prototype
//
// Design approach: rather than fabricate a full glasses frame (hinges, nose
// bridge, lens-fit) from scratch, these pods clip onto the temple arm of an
// existing pair of glasses. Two small pods instead of one big one, split by
// where the weight naturally belongs:
//   - FRONT POD: near the hinge. Houses ONLY the camera module, detached
//     from the XIAO and connected back by its FPC ribbon, plus the touch
//     pad. The camera has to be at the front (it must aim forward) but
//     nothing else does — so nothing else goes here. This is what keeps
//     the visible, forward part of the device small.
//   - REAR POD: behind the ear. Houses the XIAO board, battery and buzzer
//     (placeholder for the eventual bone-conduction transducer). Behind-
//     the-ear is where hearing aids and BTE headphones put their bulk for
//     exactly this reason — it's already physically "spoken for" on a
//     normal face, and hair covers it.
//   - The camera ribbon runs along the temple arm between the two. Route
//     it under the arm or tuck it along the top edge; a dab of removable
//     adhesive at one or two points is enough for a prototype.
//
// The temple channel is cut THROUGH the pod body rather than bolted
// underneath it, so the channel ceiling and the cavity floor share one
// wall. That's worth ~5mm of height versus stacking a separate clip.
//
// Printer: Snapmaker U1, 270x270x270mm, standard FDM. WALL and CLEARANCE
// assume a 0.4mm nozzle — adjust those two first if your profile differs.
//
// !! MEASURE BEFORE PRINTING !!
// TEMPLE_* must match the actual glasses you're clipping onto, and the
// CAM_*/XIAO_* values must match your actual parts. Everything else
// follows from those. Print ONE fit-test piece (part="fit_test") before
// committing to a full pod — it's a 3-minute print that will save you a
// wasted hour.
//
// PLACEHOLDER SIZES: no touch sensor, amp, or battery sourced yet (team
// has the Freenove Ultimate Starter Kit + XIAO Sense only). Battery and
// buzzer cavities are sized for common off-the-shelf parts so this prints
// and test-fits NOW; tighten them once real parts arrive.
//
// Render each printable part:
//   openscad -o front_base.stl -D 'part="front_base"' vocalens_pod.scad
//   openscad -o front_lid.stl  -D 'part="front_lid"'  vocalens_pod.scad
//   openscad -o rear_base.stl  -D 'part="rear_base"'  vocalens_pod.scad
//   openscad -o rear_lid.stl   -D 'part="rear_lid"'   vocalens_pod.scad
//   openscad -o fit_test.stl   -D 'part="fit_test"'   vocalens_pod.scad

/* [Print settings] */
WALL = 1.6;        // 4 perimeters at 0.4mm nozzle — don't go below 1.2
CLEARANCE = 0.3;   // fit tolerance between mating FDM parts
EPS = 0.01;        // overlap to avoid coplanar faces in unions
EDGE_RADIUS = 1.0; // outer vertical-corner rounding, softens the "square
                    // box" look. Must stay comfortably under WALL or the
                    // rounding arc eats into the cavity at the corners.
$fn = 48;

// A rectangle rounded on its vertical corners only (top/bottom stay flat) —
// cheap, and doesn't risk collapsing thin lids the way rounding every edge
// of a 1.6mm-thick slab would. Used for every outer shell in this file so
// the pods read as a soft-cornered bar rather than a printed brick.
module rounded_prism(l, w, h, r) {
  linear_extrude(height = h)
    offset(r = r)
      offset(delta = -r)
        square([l, w]);
}

/* [Temple arm — MEASURE YOUR ACTUAL GLASSES] */
TEMPLE_THICKNESS = 4.5;  // temple arm thickness (side to side), mm
TEMPLE_WIDTH = 6.0;      // temple arm width (top to bottom), mm
SNAP_GAP = 1.0;          // how much narrower the opening is than the arm

/* [Camera module — detached from the XIAO, on its FPC ribbon] */
// The OV2640 module on the Sense expansion unclips from its FPC connector
// and can sit on its own. MEASURE YOURS — these are generous placeholders.
CAM_LEN = 11;   // along the temple
CAM_WID = 11;   // across (this is what sets front-pod width)
CAM_HGT = 7;    // protrusion from the temple

/* [XIAO ESP32S3 Sense board] */
// Bare XIAO is ~21 x 17.5mm.
XIAO_LEN = 23;
XIAO_WID = 19;
// XIAO_HGT: the full board+camera STACK height, kept for the legacy
// single-pod/reference variants that still stack the camera on top of the
// board. The committed build (frontboard_base) does NOT stack them -- see
// XIAO_THICK below.
XIAO_HGT = 8;
// XIAO_THICK: the board's OWN profile only (PCB + onboard components,
// e.g. the USB connector) with the camera NOT included -- used when the
// camera sits beside the board instead of on top of it. MEASURE YOURS;
// this is a placeholder.
XIAO_THICK = 5;

/* [Battery placeholder — common 3.7V 1S LiPo, e.g. 602030] */
BATT_LEN = 30;
BATT_WID = 20;
BATT_HGT = 6;

/* [Build variant] */
// COMMITTED BUILD for this event: ONE pod holding everything, using only
// parts in the Freenove kit + XIAO Sense. No purchases, no shipping risk.
// The two-pod split and bone conduction are documented as future
// upgrades (see hardware/README.md) but are NOT part of this build.
SINGLE_POD = true;

/* [Audio output — pick one] */
// Kept false for this build: the kit speaker is what's actually on hand.
// BONE_CONDUCTION=true still renders correctly (see cad/bone_conduction/)
// as a documented future-upgrade reference for the pitch deck, but it is
// not part of the committed build since it requires an external part.
BONE_CONDUCTION = false;

/* [Speaker — the round speaker included in the Freenove kit] */
// MEASURE YOURS. Kit speakers are typically 20-28mm diameter, 5-8mm deep.
SPKR_DIA = 28;
SPKR_HGT = 6;

/* [Bone-conduction transducer — e.g. Adafruit ADA1674] */
// Mounts OUTSIDE the cavity, on the inner face, so these dimensions set
// the mounting pad, not internal volume.
BC_LEN = 21.5;
BC_WID = 14.5;
BC_HGT = 8;

/* [Audio amp — the kit's "Audio Converter & Amplifier" module] */
// MEASURE YOURS. Small I2S breakout, typically ~22 x 16 x 4mm.
AMP_LEN = 22;
AMP_WID = 16;
AMP_HGT = 5;

part = "layout"; // front_base | front_lid | rear_base | rear_lid | fit_test | layout

// Derived: the temple channel sits at the bottom of the pod body
CH_H = TEMPLE_THICKNESS + CLEARANCE;   // channel height
CH_W = TEMPLE_WIDTH + CLEARANCE;       // channel width
// Pod width is driven by whatever it has to hold, never by the channel
// alone — a pod narrower than its own contents silently won't fit them.
function body_w(content_w) = max(CH_W, content_w) + 2 * WALL;

// ---------------------------------------------------------------------
// WHICH AXIS IS WHICH, WHEN WORN (read this before changing any module
// below):
//   X (length)   — along the temple arm, front to back.
//   Y (BODY_W, driven by "content_w" below) — the arm's TOP-TO-BOTTOM
//     axis. When the pod is clipped on, growing this axis pushes the pod
//     UP into the scalp/hair and DOWN toward the ear. KEEP THIS SMALL —
//     pass a component's THICKNESS here, never its footprint.
//   Z (cav_h)    — the arm's SIDE-TO-SIDE axis, i.e. straight out away
//     from the head. There is real clearance here. Pass a component's
//     larger footprint dimension here.
// Getting content_w and cav_h backwards is exactly what made the first
// version of this design rest its bulk on top of the wearer's head
// instead of out to the side of it.
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
// Pod body: one solid block with the temple channel subtracted from the
// bottom and a component cavity opened in the top.
//   length     — along the temple arm
//   cav_h      — component cavity height
//   extras()   — additional subtractions (ports, holes), applied in the
//                body's own coordinate space
// ---------------------------------------------------------------------
module pod_body(length, cav_h, content_w) {
  BODY_W = body_w(content_w);
  total_h = WALL + CH_H + WALL + cav_h + WALL;
  difference() {
    rounded_prism(length, BODY_W, total_h, EDGE_RADIUS);

    // temple channel, running the full length, open at the bottom face
    translate([-EPS, WALL, WALL])
      cube([length + 2 * EPS, CH_W, CH_H]);

    // slot from channel down through the bottom face, narrower than the
    // arm so the pod snaps on and grips by spring tension
    translate([-EPS, WALL + SNAP_GAP / 2, -EPS])
      cube([length + 2 * EPS, CH_W - SNAP_GAP, WALL + 2 * EPS]);

    // component cavity, open at the top face
    translate([WALL, WALL, WALL + CH_H + WALL])
      cube([length - 2 * WALL, BODY_W - 2 * WALL, cav_h + WALL + EPS]);

    children();
  }
}

// cavity floor height, for positioning ports relative to the cavity
function cav_floor() = WALL + CH_H + WALL;

// ---------------------------------------------------------------------
// Press-fit lid: drops into the cavity mouth, held by friction ribs.
// ---------------------------------------------------------------------
// Ports that face upward (touch pad, sound holes) go in the LID, not the
// base: the base's cavity is open at the top, so cutting them there would
// just remove air.
module pod_lid(length, content_w, has_touch_pad = false, touch_from_end = 8,
               sound_holes = false, sound_from_end = 4, sound_count = 4) {
  lid_l = length - 2 * WALL - 2 * CLEARANCE;
  lid_w = body_w(content_w) - 2 * WALL - 2 * CLEARANCE;
  difference() {
    union() {
      rounded_prism(lid_l, lid_w, WALL, min(EDGE_RADIUS, WALL / 2));
      // friction ribs on the underside
      for (rx = [3, lid_l - 4])
        translate([rx, 0, -1.0])
          cube([1, lid_w, 1.0 + EPS]);
    }
    if (has_touch_pad)
      translate([lid_l - touch_from_end, lid_w / 2, -1])
        cylinder(h = WALL + 2, d = min(4.5, lid_w - 2));
    // speaker grille — a single row of holes along the length. Deliberately
    // NOT a 2D ring pattern: lid_w is now the pod's minimised vertical
    // dimension (often under 10mm), too narrow for a multi-ring grille.
    if (sound_holes)
      for (i = [0 : sound_count - 1])
        translate([lid_l - sound_from_end - i * 3.2, lid_w / 2, -1])
          cylinder(h = WALL + 2, d = min(1.6, lid_w - 2));
  }
}

// ---------------------------------------------------------------------
// TWO-POD, KIT-ONLY SPLIT — no FPC ribbon needed.
//
// The camera stays attached to the board (its stock ribbon is never
// touched), but it sits BESIDE the board along the temple's length, not
// stacked on top of it — the ribbon has enough slack for this on the real
// hardware. That keeps the pod's vertical (top-to-bottom) profile close to
// just a component's thickness (~5-7mm) instead of the ~15mm you'd get by
// piling the camera on top of the board. All of that bulk instead extends
// outward, away from the head, where there's actual clearance. See the
// axis note above pod_body for why this matters.
//
// The speaker (the single biggest part in this build) moves to a second
// pod behind the ear, connected by ordinary jumper wires from the kit
// (65 M-M + 20 F-F + 20 F-M -- plenty for the 5 wires needed: BCLK, LRC,
// DIN, 3V3, GND). No purchase, no fragile flex cable.
//
// FRONT POD: camera (beside the board) + XIAO board + touch pad.
// REAR POD:  amp + speaker, side by side.
// ---------------------------------------------------------------------
FB_GAP = 3; // gap between the camera and the board inside the front pod
FB_LEN = CAM_LEN + FB_GAP + XIAO_LEN + 2 * WALL + 8;  // + room for touch pad
FB_OUT = max(XIAO_WID, CAM_WID);            // outward (Z) — the footprint
FB_VERT = max(XIAO_THICK, CAM_HGT);         // vertical (Y) — the thickness

module frontboard_base() {
  fw = body_w(FB_VERT);
  pod_body(FB_LEN, FB_OUT, FB_VERT) {
    // camera lens opening — front face, centred on the camera's own
    // footprint near the inner (channel) side, not the pod's full depth
    translate([-1, fw / 2, cav_floor() + CAM_WID / 2])
      rotate([0, 90, 0])
        cylinder(h = WALL + 2, d = 7);
    // USB-C access — side face, over the board end
    translate([FB_LEN - 14, -1, cav_floor() + 2])
      cube([10, WALL + 2, 3.5]);
    // jumper-wire exit to the rear pod — rear face
    translate([FB_LEN - WALL - EPS, fw / 2 - 4, cav_floor() + 1])
      cube([WALL + 2, 8, 3]);
  }
}

module frontboard_lid() {
  pod_lid(FB_LEN, FB_VERT, has_touch_pad = true, touch_from_end = 7);
}

// Amp and speaker sit side by side along the temple's length (unchanged),
// but the pod's vertical (Y) axis now carries their THICKNESS, and their
// footprint (speaker diameter, amp width) extends outward (Z) instead.
RA_LEN = AMP_LEN + SPKR_DIA + 2 * WALL + 4;
RA_OUT = max(AMP_WID, SPKR_DIA);   // outward (Z)
RA_VERT = max(AMP_HGT, SPKR_HGT);  // vertical (Y)

module rearaudio_base() {
  rw = body_w(RA_VERT);
  pod_body(RA_LEN, RA_OUT, RA_VERT) {
    // jumper-wire entry from the front pod — front face
    translate([-1, rw / 2 - 4, cav_floor() + 1])
      cube([WALL + 2, 8, 3]);
  }
}

module rearaudio_lid() {
  pod_lid(RA_LEN, RA_VERT, sound_holes = true, sound_from_end = 6);
}

// ---------------------------------------------------------------------
// SINGLE POD — everything in one box, camera still attached to the board.
// Mount it at the FRONT of the temple so the camera aims forward.
// ---------------------------------------------------------------------
// Everything crammed into one pod is inherently the bulkiest option; the
// best available fix (without the two-pod split) is still to route each
// component's THICKNESS onto the vertical axis and its FOOTPRINT outward,
// same principle as the split pods above. Board+camera are still stacked
// here (single pod has no room to place them side by side end-to-end
// without growing very long), so this remains noticeably taller than the
// split build's front pod -- prefer split_plate.stl whenever possible.
SP_OUT = max(XIAO_WID, AMP_WID, SPKR_DIA);  // outward (Z)
SP_VERT = XIAO_HGT + CAM_HGT + AMP_HGT;     // vertical (Y) — still stacked
SP_LEN = max(XIAO_LEN, AMP_LEN) + (BONE_CONDUCTION ? 0 : SPKR_DIA) + 2 * WALL + 5;

module single_base() {
  pw = body_w(SP_VERT);
  pod_body(SP_LEN, SP_OUT, SP_VERT) {
    // camera lens opening — front face
    translate([-1, pw / 2, cav_floor() + SP_VERT / 2])
      rotate([0, 90, 0])
        cylinder(h = WALL + 2, d = 8);

    // USB-C access — side face
    translate([SP_LEN - 15, -1, cav_floor() + 2])
      cube([11, WALL + 2, 4]);

    // bone-conduction pad on the inner face, when fitted
    if (BONE_CONDUCTION) {
      translate([(SP_LEN - BC_LEN) / 2, -EPS, cav_floor() - 1])
        cube([BC_LEN, 1.0, BC_WID]);
      translate([SP_LEN / 2, WALL / 2, cav_floor() + 2])
        rotate([90, 0, 0]) cylinder(h = WALL + 2, d = 3, center = true);
    }
  }
}

module single_lid() {
  pod_lid(SP_LEN, SP_VERT, has_touch_pad = true, touch_from_end = 7,
          sound_holes = !BONE_CONDUCTION, sound_from_end = 6);
}

// ---------------------------------------------------------------------
// FRONT POD — camera module + touch pad ONLY. Kept deliberately minimal:
// this is the part people see.
// ---------------------------------------------------------------------
// Reference only (see hardware/README.md "what we'd build next" --
// this variant assumes a bought, longer FPC ribbon and is not printed for
// the committed build). Camera-only, so it's naturally small either way;
// still oriented with its footprint (CAM_WID) outward and its thickness
// (CAM_HGT) vertical, for consistency with the committed pods.
FRONT_LEN = CAM_LEN + 2 * WALL + 12;  // camera + room for the touch pad
FRONT_W = CAM_WID;   // outward (Z)

module front_base() {
  fw = body_w(CAM_HGT);
  pod_body(FRONT_LEN, FRONT_W, CAM_HGT) {
    // camera lens opening — front face, centred on the cavity
    translate([-1, fw / 2, cav_floor() + FRONT_W / 2])
      rotate([0, 90, 0])
        cylinder(h = WALL + 2, d = 7);

    // FPC ribbon exit — rear face, a flat slot back toward the rear pod
    translate([FRONT_LEN - WALL - EPS, fw / 2 - 5, cav_floor() + 1])
      cube([WALL + 2, 10, 1.5]);
  }
}

module front_lid() { pod_lid(FRONT_LEN, CAM_HGT, has_touch_pad = true); }

// ---------------------------------------------------------------------
// REAR POD — XIAO board + battery + buzzer. Sits behind the ear where
// bulk is acceptable and largely hidden.
// ---------------------------------------------------------------------
// Board and amp STACK (amp sits on the board), so the pod length is set by
// the longer of that stack and the speaker sitting next to it — not by
// adding every component end to end.
// With bone conduction the transducer lives on the outer face, so nothing
// but the board+amp stack has to fit inside — roughly half the length.
REAR_LEN = BONE_CONDUCTION
  ? max(XIAO_LEN, AMP_LEN) + 2 * WALL + 5
  : max(XIAO_LEN, AMP_LEN) + SPKR_DIA + 2 * WALL + 5;
// outward (Z): footprint dimensions
REAR_OUT = BONE_CONDUCTION
  ? max(XIAO_WID, AMP_WID)
  : max(XIAO_WID, AMP_WID, SPKR_DIA);
// vertical (Y): thickness dimensions -- board+amp still stack here since
// this reference variant keeps the board+amp arrangement from the
// original ribbon-based design; not the committed build.
REAR_VERT = BONE_CONDUCTION
  ? XIAO_HGT + AMP_HGT
  : max(XIAO_HGT + AMP_HGT, SPKR_HGT);

module rear_base() {
  rw = body_w(REAR_VERT);
  pod_body(REAR_LEN, REAR_OUT, REAR_VERT) {
    // Bone-conduction transducer pad: a shallow recess on the INNER face
    // (the side against the head) to seat the transducer, plus a wire
    // pass-through into the cavity. Firm bone contact is what makes bone
    // conduction work, so it must sit proud against the skull, not buried.
    if (BONE_CONDUCTION) {
      translate([(REAR_LEN - BC_LEN) / 2, -EPS, cav_floor() - 1])
        cube([BC_LEN, 1.0, BC_WID]);
      translate([REAR_LEN / 2, WALL / 2, cav_floor() + 2])
        rotate([90, 0, 0])
          cylinder(h = WALL + 2, d = 3, center = true);
    }
    // FPC ribbon entry from the front pod — front face
    translate([-1, rw / 2 - 5, cav_floor() + 1])
      cube([WALL + 2, 10, 1.5]);

    // USB-C access slot — side face, over the board end, so you can
    // charge and reflash without pulling the lid off
    translate([4, -1, cav_floor() + 1.5])
      cube([10, WALL + 2, 3.5]);
  }
}

// Buzzer sits at the rear end of the pod, so the sound holes go there too.
// No grille needed when the transducer is on the outer face.
module rear_lid() {
  pod_lid(REAR_LEN, REAR_VERT, sound_holes = !BONE_CONDUCTION, sound_from_end = 6);
}

// ---------------------------------------------------------------------
// FIT TEST — a 12mm slice of the clip only. Print this FIRST and check it
// snaps onto your glasses before printing a full pod. If it's loose,
// increase SNAP_GAP; if it won't go on or splays the arm, decrease it.
// ---------------------------------------------------------------------
// Only the clip mechanic is under test here, so a small nominal width is
// used rather than any component's real footprint.
module fit_test() {
  intersection() {
    pod_body(12, 3, CH_W);
    cube([12, body_w(CH_W), WALL + CH_H + WALL]);
  }
}

// ---------------------------------------------------------------------
if (part == "front_base") front_base();
else if (part == "front_lid") front_lid();
else if (part == "rear_base") rear_base();
else if (part == "rear_lid") rear_lid();
else if (part == "fit_test") fit_test();
else if (part == "single_base") single_base();
else if (part == "single_lid") single_lid();
else if (part == "frontboard_base") frontboard_base();
else if (part == "frontboard_lid") frontboard_lid();
else if (part == "rearaudio_base") rearaudio_base();
else if (part == "rearaudio_lid") rearaudio_lid();
else if (part == "split_plate") {
  // The kit-only two-pod build: front (board+camera+touch), rear
  // (amp+speaker), connected by jumper wires. No purchases.
  fw = body_w(FB_VERT);
  rw = body_w(RA_VERT);
  flw = fw - 2 * WALL - 2 * CLEARANCE;
  rlw = rw - 2 * WALL - 2 * CLEARANCE;
  gap = 8;
  translate([0, 0, 0]) frontboard_base();
  translate([FB_LEN + gap, 0, 0]) rearaudio_base();
  translate([0, fw + gap + flw, WALL]) rotate([180, 0, 0]) frontboard_lid();
  translate([FB_LEN + gap, rw + gap + rlw, WALL]) rotate([180, 0, 0]) rearaudio_lid();
  translate([0, max(fw + gap + flw, rw + gap + rlw) + gap + 6, 0]) fit_test();
}
else if (part == "single_plate") {
  // The one-pod build: three parts, everything you need for Friday.
  pw = body_w(SP_VERT);
  lw = pw - 2 * WALL - 2 * CLEARANCE;
  translate([0, 0, 0]) single_base();
  translate([0, pw + 8 + lw, WALL]) rotate([180, 0, 0]) single_lid();
  translate([SP_LEN + 8, 0, 0]) fit_test();
}
else if (part == "plate") {
  // Everything on one bed, spaced 8mm apart. This is the single file to
  // slice if you just want to print the whole thing in one go.
  //
  // The lids are FLIPPED rib-side-up here. Their friction ribs protrude
  // below the plate, so printed as-modelled the plate would float 1mm off
  // the bed and the slicer would add supports under it. Flipped, the flat
  // face is on the bed and the ribs print as small upward bumps — no
  // supports, better surface finish on the visible side.
  fw = body_w(CAM_HGT);
  rw = body_w(REAR_VERT);
  // A flipped lid extends BACKWARDS in Y from its origin, so each lid's
  // own width has to be added to the offset or it overlaps the base in
  // front of it. Getting this wrong fuses two parts into one on the plate.
  flw = fw - 2 * WALL - 2 * CLEARANCE;   // front lid width
  rlw = rw - 2 * WALL - 2 * CLEARANCE;   // rear lid width
  gap = 8;

  translate([0, 0, 0])             front_base();
  translate([FRONT_LEN + gap, 0, 0]) rear_base();
  translate([0, fw + gap + flw, WALL])
    rotate([180, 0, 0]) front_lid();
  translate([FRONT_LEN + gap, rw + gap + rlw, WALL])
    rotate([180, 0, 0]) rear_lid();
  translate([0, max(fw + gap + flw, rw + gap + rlw) + gap + 6, 0])
    fit_test();
}
else {
  translate([0, 0, 0])   front_base();
  translate([0, 20, 0])  front_lid();
  translate([0, 36, 0])  rear_base();
  translate([0, 52, 0])  rear_lid();
  translate([55, 0, 0])  fit_test();
}
