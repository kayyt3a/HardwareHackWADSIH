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
$fn = 48;

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

/* [XIAO ESP32S3 Sense board — lives in the REAR pod] */
// Bare XIAO is ~21 x 17.5mm; height is the board + Sense expansion stack
// WITHOUT the camera module, since that's now up front.
XIAO_LEN = 23;
XIAO_WID = 19;
XIAO_HGT = 8;

/* [Battery placeholder — common 3.7V 1S LiPo, e.g. 602030] */
BATT_LEN = 30;
BATT_WID = 20;
BATT_HGT = 6;

/* [Buzzer placeholder — Freenove kit passive buzzer] */
BUZZER_DIA = 13;
BUZZER_HGT = 9;

part = "layout"; // front_base | front_lid | rear_base | rear_lid | fit_test | layout

// Derived: the temple channel sits at the bottom of the pod body
CH_H = TEMPLE_THICKNESS + CLEARANCE;   // channel height
CH_W = TEMPLE_WIDTH + CLEARANCE;       // channel width
// Pod width is driven by whatever it has to hold, never by the channel
// alone — a pod narrower than its own contents silently won't fit them.
function body_w(content_w) = max(CH_W, content_w) + 2 * WALL;

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
    cube([length, BODY_W, total_h]);

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
      cube([lid_l, lid_w, WALL]);
      // friction ribs on the underside
      for (rx = [3, lid_l - 4])
        translate([rx, 0, -1.0])
          cube([1, lid_w, 1.0 + EPS]);
    }
    if (has_touch_pad)
      translate([lid_l - touch_from_end, lid_w / 2, -1])
        cylinder(h = WALL + 2, d = 6);
    if (sound_holes)
      for (i = [0 : sound_count - 1])
        translate([lid_l - sound_from_end - i * 3.5, lid_w / 2, -1])
          cylinder(h = WALL + 2, d = 1.6);
  }
}

// ---------------------------------------------------------------------
// FRONT POD — camera module + touch pad ONLY. Kept deliberately minimal:
// this is the part people see.
// ---------------------------------------------------------------------
FRONT_LEN = CAM_LEN + 2 * WALL + 12;  // camera + room for the touch pad
FRONT_W = CAM_WID;

module front_base() {
  fw = body_w(FRONT_W);
  pod_body(FRONT_LEN, CAM_HGT, FRONT_W) {
    // camera lens opening — front face, centred on the cavity
    translate([-1, fw / 2, cav_floor() + CAM_HGT / 2])
      rotate([0, 90, 0])
        cylinder(h = WALL + 2, d = 7);

    // FPC ribbon exit — rear face, a flat slot back toward the rear pod
    translate([FRONT_LEN - WALL - EPS, fw / 2 - 5, cav_floor() + 1])
      cube([WALL + 2, 10, 1.5]);
  }
}

module front_lid() { pod_lid(FRONT_LEN, FRONT_W, has_touch_pad = true); }

// ---------------------------------------------------------------------
// REAR POD — XIAO board + battery + buzzer. Sits behind the ear where
// bulk is acceptable and largely hidden.
// ---------------------------------------------------------------------
REAR_LEN = XIAO_LEN + BATT_LEN + 2 * WALL + 6;
REAR_W = max(XIAO_WID, BATT_WID, BUZZER_DIA);
REAR_CAV_H = max(XIAO_HGT, BATT_HGT, BUZZER_HGT);

module rear_base() {
  rw = body_w(REAR_W);
  pod_body(REAR_LEN, REAR_CAV_H, REAR_W) {
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
module rear_lid() { pod_lid(REAR_LEN, REAR_W, sound_holes = true); }

// ---------------------------------------------------------------------
// FIT TEST — a 12mm slice of the clip only. Print this FIRST and check it
// snaps onto your glasses before printing a full pod. If it's loose,
// increase SNAP_GAP; if it won't go on or splays the arm, decrease it.
// ---------------------------------------------------------------------
module fit_test() {
  intersection() {
    pod_body(12, 3, FRONT_W);
    cube([12, body_w(FRONT_W), WALL + CH_H + WALL]);
  }
}

// ---------------------------------------------------------------------
if (part == "front_base") front_base();
else if (part == "front_lid") front_lid();
else if (part == "rear_base") rear_base();
else if (part == "rear_lid") rear_lid();
else if (part == "fit_test") fit_test();
else {
  translate([0, 0, 0])   front_base();
  translate([0, 20, 0])  front_lid();
  translate([0, 36, 0])  rear_base();
  translate([0, 52, 0])  rear_lid();
  translate([55, 0, 0])  fit_test();
}
