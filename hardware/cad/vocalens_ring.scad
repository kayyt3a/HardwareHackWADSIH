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
// HOW FAR UNDERSIZED — there is a right amount, and it is not "as much as
// possible". TPU grips hardest at roughly 20-30% strain. Past that it stops
// being a press fit and becomes a fight: the ring will not go on at all, or it
// goes on stretched so far that it takes a permanent set and grips worse than
// a milder one would have. An opening of 5.0 x 2.2 was tried against a real
// arm and could not be fitted — that is around 120% strain on the thin axis.
//
// So aim for about 75-85% of the arm's actual section, and measure the arm
// rather than assuming. Print the ladder below if you have not measured.
RING_IN_VERT  = 7.5;  // Y — vs an arm of roughly 9-10mm height
RING_IN_OUT   = 3.4;  // Z — vs an arm of roughly 4-5mm thickness
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

// Measured on printed parts: the joint was too tight to assemble, so the slot
// gets this much more on top of CLEARANCE. It is applied to the SLOT ONLY, not
// to the rail, because the rail's size is also what grips — shrinking the rail
// instead would loosen the joint twice over.
//   net per face = DT_SQUISH - CLEARANCE - DT_SLOT_EXTRA
// which is now slightly negative, i.e. a sliding fit rather than a press fit.
// That is deliberate: the TPU ring is soft enough that friction down the length
// of the rail still holds the pod, and a joint that cannot be assembled is
// worth nothing.
DT_SLOT_EXTRA = 0.5;

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
// DEFAULT IS false, and it is a decision about the build, not a preference.
//
// false means the amp has wires soldered flat to its pads. It is 10mm slimmer
// than the socketed version and it is the design we are shipping, because that
// 10mm comes straight off the pod sitting against the wearer's head.
//
// If your amp has header pins with jumper sockets pushed onto them, this pod
// WILL NOT CLOSE over it. Either wire the amp flat, or override this back to
// true and accept the taller rear pod:
//   openscad -D AMP_HEADERS_FITTED=true ...
AMP_HEADERS_FITTED = false;
AMP_PROFILE        = AMP_HEADERS_FITTED ? HEADER_STACK : AMP_HGT;

// ---------------------------------------------------------------- pod sizing
// The two trailing constants below are SLACK — room for wire bends and for
// components sitting a little proud of their nominal size. They were set
// generously while the layout was still moving. Now that it is fixed they are
// cut to the minimum that still lets a wire turn a corner: every millimetre
// here is length hanging off the side of someone's face.
// ---------------------------------------------------- measured corrections
// From handling the first printed set. Kept as named additions rather than
// folded into the formulas, so it stays obvious what is a component dimension
// and what is a correction someone made holding the part.
//
// RA_EXTRA_OUT is the big one: the rear cavity was 8mm deep for a 5mm amp,
// leaving 3mm for wiring, and the wires would not fit under the lid.
FB_EXTRA_LEN = 5; FB_EXTRA_VERT = 3;  FB_EXTRA_OUT = 0;
RA_EXTRA_LEN = 5; RA_EXTRA_VERT = 3;  RA_EXTRA_OUT = 15;

FB_GAP  = 1.5;
FB_LEN  = CAM_LEN + FB_GAP + XIAO_LEN + 2 * WALL + 3 + FB_EXTRA_LEN;
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
// FB_VERT_MIN lets the front pod be widened past what the components need, so
// the lid can carry a bigger touch pad. It costs vertical height at the hinge,
// which is the cheap axis, but the front pod is the one in peripheral vision —
// so spend it deliberately, not by default.
// 28 rather than 0. The camera pod is no longer sized by the XIAO (19mm) but
// by what the lid has to carry: a 28.52mm coin needs a lid at least 31mm wide.
// With FB_EXTRA_VERT this puts the pod at 34.2mm outer — the same width as the
// audio pod, which is also what makes the two sides look like a matched pair
// rather than two different objects.
FB_VERT_MIN = 28;
FB_VERT = max(XIAO_WID, CAM_WID, FB_VERT_MIN) + FB_EXTRA_VERT;   // vertical (Y)
FB_OUT  = max(XIAO_PROFILE, CAM_HGT) + WIRE_ROOM + FB_EXTRA_OUT; // outward (Z)

RA_LEN  = AMP_LEN + SPKR_DIA + 2 * WALL + 2 + RA_EXTRA_LEN;
// Same for the rear pod, and it matters more here: the speaker's 28mm was the
// single biggest number in the build and it was pointed straight out sideways.
// On edge it runs vertically, behind the ear, where the ear itself hides it —
// which is exactly where a behind-the-ear hearing aid puts the same bulk.
RA_VERT = max(AMP_WID, SPKR_DIA) + RA_EXTRA_VERT;
RA_OUT  = max(AMP_PROFILE, SPKR_HGT) + WIRE_ROOM + RA_EXTRA_OUT;

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

module temple_ring(in_vert = RING_IN_VERT, in_out = RING_IN_OUT) {
  ow = in_vert + 2 * RING_WALL;   // outer, Y
  oh = in_out  + 2 * RING_WALL;   // outer, Z
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
      cube([RING_LEN + 2 * EPS, in_vert, in_out]);
  }
}

// ------------------------------------------------------------ the sliding lid
// The lid slides in from the REAR along X and stops against the inside of the
// front end wall, which also registers the camera hole.
//
// WHY THE GROOVES CUT OUTWARD INTO THE WALLS, not inward over the cavity.
// The components drop in through the top, and the front pod's cavity is
// exactly as wide as the XIAO (19mm) — it has to be, that is what set the
// dimension. Any lip overhanging inward would block the board from going in at
// all. So the groove is cut sideways INTO each side wall: at the groove's
// height the wall's inner face steps back by GROOVE_D, and above the groove it
// returns. The lid is therefore wider than the cavity, its edges live inside
// the walls, and the full cavity width stays clear from above.
//
// That is also why the lid cannot be dropped in — it is wider than the hole it
// covers. It only goes in endwise, which is the point.
// 3.2, not 1.6. The touch pad is a 20c coin, 2.5mm thick, and a recess has to
// be shallower than the plate it is cut into — a 2.5mm pocket in a 1.6mm lid
// is a hole, and the coin falls through it. At 3.2 the coin recesses fully and
// still leaves 0.7mm of lid under it. Costs 1.6mm of outward depth on both
// pods, which is the cheapest place to spend it.
LID_T      = 3.2;   // lid plate thickness
LID_LIP    = 1.0;   // wall left above the groove — this is what retains it
LID_GROOVE = 1.0;   // how far the groove cuts into each side wall
LID_CLR    = 0.25;  // sliding clearance, per face
LID_DETENT = 0.3;   // click bump near the entry. Set to 0 for a plain friction
                    // slide if the lid will not go in.

// ============================================================================
// pod base — rigid box with the dovetail slot underneath
// ============================================================================

// Height of the groove floor above the pod's own floor — i.e. the top of the
// usable component space. Shared by the base and the lid so they cannot drift.
function groove_z(out) = WALL + out;
function pod_height(out) = WALL + out + LID_T + LID_LIP;
function lid_len(length) = length - WALL - LID_CLR;
function lid_wid(vert)   = vert + 2 * LID_GROOVE - 2 * LID_CLR;

// ------------------------------------------------------- camera aperture
// The camera looks FORWARD, along the arm, so its aperture belongs in the
// front END WALL — not in the lid. The lid is the outward face: a hole there
// points the lens sideways, square out of the side of the wearer's head, at
// whatever happens to be to their left.
//
// It is a vertical SLOT rather than a round hole. The camera hangs off a short
// ribbon from a board standing on edge, so exactly where it ends up in the
// cavity is not knowable from the CAD — the slot lets it sit anywhere in a
// 12mm band and still see out.
// Cable pass-throughs. Sized so the five-wire bundle (~3.8mm) passes without
// being pinched, AND so the sleeve that butts up against it (6.6 x 5.4mm outer)
// is not wider than the hole it feeds — a sleeve that cannot reach the pod
// leaves a bare gap at each end, which is exactly where the wires are most
// visible and most likely to be tugged.
//
// Stadium-shaped, not a square cut: wire crossing a sharp corner under repeated
// head movement is how insulation chafes through.
CABLE_W = 9;   // across the wall (Y)
CABLE_H = 6;   // up the wall (Z)

// TUBE SOCKET. A short boss on the outside of the end wall that the cable tube
// pushes into, so the tube is retained rather than merely butted against a
// hole — otherwise it slides back under any tug and bares the wire at exactly
// the two points where that looks worst.
//
// Deliberately NOT a dovetail. A dovetail resists lift-off perpendicular to
// its slide axis; the load here is axial pull-out, straight along the tube,
// which a dovetail does nothing about. An interference socket resists it
// directly — and it is the same trick the ring/rail joint already uses: soft
// TPU squeezed into rigid PETG, where the tolerance is absorbed by the soft
// part.
//
// The socket bore is UNDER the tube's outside diameter on purpose.
TUBE_SOCKET_L       = 6;     // how far the tube goes in
TUBE_SOCKET_SQUEEZE = 0.3;   // socket is this much smaller than the tube

CAM_APERTURE_W = 7.5;   // across the wall (Y)
CAM_APERTURE_H = 12;    // up the wall (Z) — the latitude

module pod_base(length, out, vert, cable_slot_front = true,
                camera_front = false, tube_socket_rear = false) {
  bw = vert + 2 * WALL;                  // Y outer
  bh = pod_height(out);                  // Z outer
  slot_pad = DT_HEIGHT + WALL;           // extra Z for the slot boss
  gz = groove_z(out);

  union() {

  // Detent bumps standing proud of the groove floor, one per side, a few mm in
  // from the entry. The lid flexes over them and drops behind them, so it does
  // not walk out on its own. Half-round, so they lead in rather than catch.
  //
  // ADDED OUTSIDE THE difference() ON PURPOSE. Put inside it, the groove cut
  // that runs along this exact band shears their top half off and leaves the
  // rest buried in solid wall — present in the file, absent from the part, and
  // silent about it. LID_DETENT = 0 removes them properly.
  // Socket boss on the rear end wall. Outside the difference() below for the
  // same reason the detents are: the cable pass-through is cut along this axis
  // and would hollow the boss out from the inside.
  if (tube_socket_rear)
    difference() {
      translate([length, bw / 2, WALL + out / 2]) rotate([0, 90, 0])
        cylinder(h = TUBE_SOCKET_L,
                 d = TUBE_OD - TUBE_SOCKET_SQUEEZE + 2 * WALL, $fn = 48);
      translate([length - EPS, bw / 2, WALL + out / 2]) rotate([0, 90, 0])
        cylinder(h = TUBE_SOCKET_L + 2 * EPS,
                 d = TUBE_OD - TUBE_SOCKET_SQUEEZE, $fn = 48);
    }

  if (LID_DETENT > 0)
    for (y0 = [WALL - LID_GROOVE, WALL + vert])
      translate([length - 7, y0, gz])
        rotate([-90, 0, 0])
          cylinder(h = LID_GROOVE, r = LID_DETENT, $fn = 20);

  difference() {
    union() {
      rounded_prism(length, bw, bh, EDGE_RADIUS);
      // boss on the underside carrying the dovetail slot
      translate([0, bw / 2 - (DT_HEAD + 2 * WALL) / 2, -slot_pad])
        rounded_prism(length, DT_HEAD + 2 * WALL, slot_pad + EPS, 0.8);

    }

    // Component cavity, open at the top (+Z) so the lid can close it.
    //
    // The height is out + WALL, NOT out + EPS. The cavity floor is at z = WALL
    // and the pod's top face is at out + 2*WALL, so a cut of only out + EPS
    // stops 1.59mm short and leaves the box sealed — a closed shell you cannot
    // get the electronics into, and nowhere for the lid's rib to drop. It looks
    // correct in a render from outside and passes a watertight check, because a
    // sealed void is perfectly manifold.
    translate([WALL, WALL, WALL])
      cube([length - 2 * WALL, vert, out + LID_T + LID_LIP + EPS]);

    // The lid channel. Cut into both side walls, running from the inside face
    // of the FRONT end wall (x = WALL, which is the lid's stop) out through the
    // rear (x = length), which is the end it slides in from.
    translate([WALL, WALL - LID_GROOVE, gz])
      cube([length - WALL + EPS, vert + 2 * LID_GROOVE, LID_T]);

    // dovetail slot, cut all the way through in X so it slides on
    translate([-EPS, bw / 2, -slot_pad])
      dovetail(length + 2 * EPS, CLEARANCE + DT_SLOT_EXTRA);

    // Forward-looking camera aperture through the front end wall, centred on
    // the cavity. Stadium-shaped so the ends are round and it prints cleanly.
    if (camera_front) {
      acz = WALL + out / 2;                     // centre of the cavity
      span = CAM_APERTURE_H - CAM_APERTURE_W;   // centre-to-centre of the ends
      translate([-EPS, bw / 2, acz])
        rotate([0, 90, 0])
          hull()
            for (dz = [-span / 2, span / 2])
              translate([dz, 0, 0])
                cylinder(h = WALL + 2 * EPS, d = CAM_APERTURE_W, $fn = 40);
    }

    // Cable pass-throughs, front and rear.
    for (spec = [[cable_slot_front, -EPS], [true, length - WALL - EPS]])
      if (spec[0]) {
        cspan = CABLE_W - CABLE_H;
        translate([spec[1], bw / 2, WALL + out / 2])
          rotate([0, 90, 0])
            hull()
              for (dy = [-cspan / 2, cspan / 2])
                translate([0, dy, 0])
                  cylinder(h = WALL + 2 * EPS, d = CABLE_H, $fn = 32);
      }
  }
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
// Sized for an Australian 20c: 28.52mm across, 2.50mm thick. PAD_L is set
// equal to PAD_W so the stadium collapses to a circle and the coin sits in a
// round pocket rather than a slot with the coin rattling along it.
PAD_W      = 29.0;  // 28.52 coin + clearance. Clamped to lid width - 2 in code.
PAD_L      = 29.0;  // equal to PAD_W -> a circle, not a stadium
PAD_DEPTH  = 2.6;   // 20c is 2.50mm; this seats it just below flush.
                    // Clamped in code to leave 0.6mm of lid under the pocket:
                    // a recess as deep as the plate is not a recess, it is a
                    // hole, and the pad would fall through it.
PAD_WIRE_D = 2.2;   // pass-through for the trigger wire

// The lid is now a flat plate that slides into the base's side grooves. It has
// no rib: the groove locates it in Y and Z, and the front end wall stops it in
// X, so there is nothing left for a rib to do.
//
// Feature positions are given in LID-LOCAL x, and the lid's origin sits at
// x = WALL in pod coordinates (hard against the front end wall). So a feature
// meant to land at pod x = P is written here as P - WALL. Get this wrong and
// the camera looks into the inside of a wall.
module pod_lid(length, out, vert, camera_hole = false, touch_recess = false,
               grille = false) {
  ll = lid_len(length);
  lw = lid_wid(vert);

  difference() {
    rounded_prism(ll, lw, LID_T, 0.8);

    // camera: pod x = WALL + 6, so lid-local x = 6
    if (camera_hole)
      translate([6, lw / 2, -EPS])
        cylinder(h = LID_T + 2 * EPS, d = 7, $fn = 40);

    if (touch_recess) {
      if (TRIGGER_IS_BUTTON) {
        translate([ll - 10, lw / 2, -EPS])
          cylinder(h = LID_T + 2 * EPS, d = BUTTON_PLUNGER_D, $fn = 32);
        translate([ll - 10, lw / 2, LID_T - 0.5])
          cylinder(h = 0.5 + EPS, d = BUTTON_PLUNGER_D + 3, $fn = 32);
      } else {
        pad_w = min(PAD_W, lw - 2);        // never breach the lid's own edges
        pad_d = min(PAD_DEPTH, LID_T - 0.6);
        cx    = ll - PAD_L / 2 - 4;
        span  = PAD_L - pad_w;

        translate([cx, lw / 2, LID_T - pad_d])
          hull()
            for (dx = [-span / 2, span / 2])
              translate([dx, 0, 0])
                cylinder(h = pad_d + EPS, d = pad_w, $fn = 40);

        // wire pass-through: straight through the plate, no rib in the way now
        translate([cx, lw / 2, -EPS])
          cylinder(h = LID_T + 2 * EPS, d = PAD_WIRE_D, $fn = 24);
      }
    }

    if (grille)
      for (a = [0 : 60 : 359], r = [2.6, 5.2])
        translate([ll - 14 + r * cos(a), lw / 2 + r * sin(a), -EPS])
          cylinder(h = LID_T + 2 * EPS, d = 1.8, $fn = 16);
  }
}

// ============================================================================
// parts
// ============================================================================

// cable_slot_front = false: the front wall is the lens aperture now, and the
// wires leave rearward toward the back of the head. The old front slot fell
// entirely inside the aperture anyway — invisible, but it weakened the wall
// the camera looks through for nothing.
module frontboard_base() { pod_base(FB_LEN, FB_OUT, FB_VERT,
                                   cable_slot_front = false,
                                   camera_front = true,
                                   tube_socket_rear = true); }
// No camera_hole: the aperture moved to the base's front end wall, so the lid
// carries only the touch pad.
module frontboard_lid()  { pod_lid(FB_LEN, FB_OUT, FB_VERT,
                                   touch_recess = true); }
module rearaudio_base()  { pod_base(RA_LEN, RA_OUT, RA_VERT,
                                   tube_socket_rear = true); }
module rearaudio_lid()   { pod_lid(RA_LEN, RA_OUT, RA_VERT, grille = true); }

// Four rings: two per pod (front and back of each) so each pod is held at two
// points and can't rock. Printing four also gives you spares.
module ring_set() {
  for (i = [0 : 3])
    translate([i * (RING_LEN + 4), 0, 0]) temple_ring();
}

// FIT LADDER — four rings, each a step larger, for when the arm has not been
// measured. Print it once, find the smallest one that will go on, then set
// RING_IN_VERT / RING_IN_OUT to that pair and print four of those.
//
// They are laid out smallest-first and each step is visibly bigger than the
// last, so the plate is self-labelling: the order on the bed is the order in
// the table. Nothing about the dovetail rail changes between them, so every
// size mates with the same pod.
RING_LADDER = [[6.0, 2.8], [7.5, 3.4], [9.0, 4.0], [10.5, 4.6]];

module ring_ladder() {
  for (i = [0 : len(RING_LADDER) - 1])
    translate([i * (RING_LEN + 4), 0, 0])
      temple_ring(RING_LADDER[i][0], RING_LADDER[i][1]);
}

// ============================================================================
// cable tube — the run around the back of the head
// ============================================================================
// CLOSED, not split. An earlier version was a channel with an open mouth: it
// tidied five loose wires into one line but you could still see straight down
// onto them, which is not concealment. This is a sealed tube — the wires go
// inside and there is no line of sight to them anywhere along the run.
//
// That is only possible because the bundle can be threaded, and it can only be
// threaded one way round:
//   * the camera-pod end carries Dupont sockets (2.6 x 5.0mm, 5.64mm across the
//     diagonal) which will NOT pass a 5mm bore;
//   * the audio-pod end is bare, because the amp is wired flat.
// So the bare ends are fed in at the camera end and come out at the amp, and
// the connectors stay outside the tube entirely.
//   >>> THREAD THE TUBE BEFORE SOLDERING THE AMP. <<<
// Soldering first makes both ends un-threadable and the only way back is to cut
// a wire.
//
// D-SECTION, flattened along the bottom. A round tube 180mm long touches the
// bed on a single line and peels off it in TPU. The flat gives a 3.7mm contact
// strip, and it also sits better against the neck than a round one rolls.
//
// Two pieces rather than one: 360mm does not fit on a hobby bed in any
// orientation, and the joint lands at the back of the head where it is under
// hair.
TUBE_BORE  = 5.0;    // bundle packs to ~4.2mm
TUBE_WALL  = 1.2;
TUBE_OD    = TUBE_BORE + 2 * TUBE_WALL;
TUBE_FLAT  = 0.5;    // sliced off the underside for bed adhesion
// PRINTED PRE-CURVED, not straight.
//
// A straight tube forced round a head is a spring: every millimetre of it is
// storing energy and pushing back, and it has only two places to push against
// — the two pods, which are held on by friction against TPU rings. The cord
// would slowly walk them off. Curving it to the shape it will be worn in means
// it sits there instead of fighting.
//
// TUBE_R = 95 because the back of a human head is roughly that. The curve is a
// constant radius rather than a real head profile: the temple runs are
// straighter than the back is, but TPU straightens far more easily than it
// bends, so erring toward the tighter curve leaves the easy correction.
//
// Split in two because a 430mm arc at R=95 needs a ~200mm bed in both axes.
// Halved, each piece is a 130 degree crescent and fits anything. Set
// TUBE_PIECES = 1 on a 220mm bed for a single continuous run and no joint.
TUBE_TOTAL  = 450;   // whole run, temple to temple around the back
TUBE_PIECES = 2;
TUBE_LEN    = TUBE_TOTAL / TUBE_PIECES;
TUBE_R      = 95;    // curve radius as printed

// Profile x is the tube's HEIGHT and runs negative — rotate([0,90,0]) maps
// (x,y,z) -> (z,y,-x), so the extrusion axis becomes X and the profile's x is
// negated on its way to Z. Positive here would put the tube under the bed.
// Cross-section for rotate_extrude, which reads a 2D shape in the +X half of
// the XY plane and maps x -> radius, y -> Z. So here x is the RADIAL width and
// y is the height off the bed, with the flat at the bottom and the whole
// section lifted so it starts at y = 0.
module tube_section_2d() {
  translate([0, TUBE_OD / 2 - TUBE_FLAT])
    difference() {
      intersection() {
        circle(d = TUBE_OD, $fn = 64);
        translate([-TUBE_OD, -TUBE_OD / 2 + TUBE_FLAT])
          square([2 * TUBE_OD, 2 * TUBE_OD]);   // slice the underside flat
      }
      circle(d = TUBE_BORE, $fn = 64);
    }
}

module cable_tube(len = TUBE_LEN, r = TUBE_R) {
  rotate_extrude(angle = len / r * 180 / PI, $fn = 260)
    translate([r, 0]) tube_section_2d();
}

// Straight version, kept for a bench test of the electrical run before the
// real one is committed to.
module cable_tube_straight(len = TUBE_LEN) {
  translate([0, 0, -TUBE_FLAT])
    rotate([0, 90, 0]) linear_extrude(height = len)
      rotate([0, 0, -90]) tube_section_2d();
}

// Each crescent is rotated to sit symmetrically about the Y axis — a shallow
// bowl rather than a tipped-over C. A 130 degree arc laid at its natural
// orientation is 162 x 99mm; the same arc centred is 180 x 62mm, because the
// bounding box then follows the chord and the sagitta instead of the radius.
// Stacked, that is the difference between needing a 220mm bed and a 200mm one.
module tube_plate() {
  sweep = TUBE_LEN / TUBE_R * 180 / PI;
  pitch = TUBE_R * (1 - cos(sweep / 2)) + TUBE_OD + 6;
  for (i = [0 : TUBE_PIECES - 1])
    translate([0, i * pitch, 0])
      rotate([0, 0, 90 - sweep / 2]) cable_tube();
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

  // Lids are plain plates now — they lie flat either way up and need no
  // rotation and no support.
  translate([0, fbw + 14, 0]) frontboard_lid();
  translate([FB_LEN + 8, raw + 14, 0]) rearaudio_lid();
}

// Everything soft, one plate, TPU.
module tpu_plate()  { ring_set(); }
module tpu_ladder() { ring_ladder(); }
module tpu_tubes()   { tube_plate(); }

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
else if (part == "tpu_ladder")      tpu_ladder();
else if (part == "tpu_tubes")       tpu_tubes();
else if (part == "cable_tube")      cable_tube();
// "none" renders nothing. Needed so another file can `include` this one for
// its modules and constants without the selector below also emitting a plate
// into that file's output.
else if (part == "none")            ;
else                                petg_plate();
