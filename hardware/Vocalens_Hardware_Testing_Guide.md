# Vocalens Hardware Testing Guide — From Zero

This is a complete, from-scratch guide to testing the physical electronics your
teammate built, written for someone who has never done electronics before.
Every concept is explained before it's used. Follow it top to bottom, in order.

**Ground rule for the whole guide:** if a step ever says "power OFF," that
means the USB cable is physically unplugged from the board. Not "the code
isn't running" — unplugged. Several early steps exist specifically to catch
problems *before* you ever apply power, because a wiring mistake found before
power is a five-minute fix, and the same mistake found after power can
destroy a $20+ board in under a second.

---

## Part 0 — What is this thing, in plain terms

### What's in the GitHub repo

The repo is just a folder of files your team has been working from. Three
folders matter to you:

- **`firmware/`** — the program that will eventually run *on* the small
  circuit board itself (the "brain" of the glasses). Written in C++.
- **`server/`** — a separate program that runs on a laptop, not on the board.
  It receives a photo, asks an AI to read it, and sends back an audio reply.
  You don't need this for hardware testing, but you'll use a small piece of
  it later (Stage 6b).
- **`hardware/`** — instructions and 3D-printable files for the physical
  case ("pods") the electronics sit inside. Background reading, not part of
  electrical testing.

Inside `firmware/`, there's a file called **`selftest.cpp`**. This is a
*diagnostic* program — a separate, simpler program from the "real" one, whose
only job is to test each piece of the hardware one at a time and tell you in
plain text whether it works. This is the single most useful file for what
you're about to do, and most of this guide is built around using it.

### What the physical build actually is

Picture a pair of glasses with two small plastic boxes clipped onto one arm
(temple), joined by a handful of thin wires:

- **Front box (near the hinge):** contains the "brain" (a small circuit
  board) and a tiny camera. Also has a coin or screw-head glued to it that
  acts as a touch button.
- **Back box (behind the ear):** contains an amplifier chip and a small
  round speaker.
- **Wires between the two boxes:** carry power and an audio signal from the
  front box to the back box.

### The components, one at a time

**XIAO ESP32S3 Sense (the "board" or "microcontroller")**
This is a tiny computer, about the size of a large postage stamp. Think of
it as a very small, very limited laptop: it can run a program (the
firmware), talk to a camera, listen to a microphone, connect to WiFi, and
send electrical signals out through small metal contact points called
**pins**. It has no screen or keyboard of its own — you talk to it by
plugging it into your laptop with a USB cable.

**Camera**
A small image sensor on a short ribbon (flat flexible strip) that plugs
into the board. It takes photos when the firmware tells it to.

**Amplifier ("amp") module**
Electrical signals from the board are very weak — far too weak to move a
speaker cone and make sound you can hear. The amp's only job is to take
that weak signal and boost it into something strong enough to drive the
speaker. Think of it like a megaphone for an electrical signal.

**Speaker**
Converts the amplified electrical signal into actual sound waves you hear.

**Touch pad (a coin or screw head)**
Just a piece of bare metal, wired to one pin on the board. The board can
sense when a finger is touching a piece of metal connected to it (more on
this in Stage 6). There's no separate "touch sensor" component — the metal
disc *is* the sensor, and the board's built-in capability does the work.

**Jumper wires**
Ordinary short wires with connectors on the ends, used to link components
together without soldering. Some of your teammate's connections are
soldered (permanent) and some may be jumper wires (removable, pushed onto
pins) — you'll figure out which is which in Stage 1.

---

## Part 1 — Concepts you need before touching anything

Read this whole part once, even the bits that seem irrelevant right now.
You'll be referred back to specific paragraphs throughout the guide.

### Electricity, in one analogy

Electricity is easiest to understand as water flowing through pipes.

- **Voltage** is like water pressure — how hard the electricity is being
  "pushed." Measured in **volts (V)**. Your board runs on **3.3 volts**
  (often written "3V3"), which is low — nowhere near dangerous to a person
  — but it *can* instantly destroy small electronic components if
  connected wrong, the way a garden hose at the wrong pressure can burst a
  cheap fitting even though it can't hurt your hand.
- **Current** is like the actual flow rate of water — how much electricity
  is moving. Measured in **amps (A)**, or for small electronics, in
  thousandths of an amp, **milliamps (mA)**.
- **Resistance** is like a narrowing in the pipe that restricts flow.
  Measured in **ohms (Ω)**. Wires have very low resistance (electricity
  flows through them easily, on purpose). Components like resistors add
  resistance on purpose to control how much current flows.
- **A circuit** is a complete loop the electricity can flow around — like a
  loop of pipe with a pump. Electricity only flows if the loop is
  complete. If you cut the loop anywhere, nothing flows anywhere in it.

### Ground / GND

Every circuit needs a "return path" — somewhere the electricity flows back
to after doing its job, to complete the loop. In small electronics, this
return path is called **ground**, abbreviated **GND**. It's not literally
connected to the earth; it's just the agreed "zero volts" reference point
that everything else in the circuit is measured against. Every single
component in this build — the board, the amp, the speaker circuit — shares
one common GND. If GND isn't properly connected somewhere, that whole
branch of the circuit won't work, even if everything else looks fine.

### Short circuit

A short circuit is when electricity finds an *unintended* path between two
points that skips around the components that are supposed to control or
use it — most dangerously, a direct wire-to-wire connection straight
between power (3V3) and GND with nothing in between to limit the flow.

Using the water analogy: it's like connecting the output of a water pump
directly back to its own intake with a wide-open pipe and nothing in the
loop to do useful work. The pump doesn't do anything useful, and it can
overheat trying to push against zero resistance.

In electronics, a short from power to ground means current has almost
nothing limiting it, so it can spike very high, very fast. This produces
heat, and can permanently destroy the board or amp in under a second, with
no warning. **This is the single most important failure mode we're
checking for before you ever plug in power**, because unlike most mistakes,
a bad short can happen the instant power is applied — there's no "test it
carefully and back off if something seems wrong," it can already be too
late by the time you notice.

### Power, VCC / 3V3

"Power" just means a voltage source available for a circuit to use. On this
board, you'll see a pin actually labeled **3V3** — this is the board's
regulated 3.3-volt power output, and it's what your amp draws its power
from. (Some boards label this pin "VCC" instead; on the XIAO board used
here, it's specifically labeled 3V3, and there's a separate 5V pin you are
**not** using for this connection.)

### GPIO, signal, input/output

**GPIO** stands for "General Purpose Input/Output" — a pin on the board
that firmware can use either to:
- **read** an electrical state from the outside world (input) — e.g.
  "is this touch pad being touched right now?", or
- **send** an electrical state out to the outside world (output) — e.g.
  "tell the amp module what audio data to play right now."

A **signal** just means "information carried as a changing voltage on a
wire," as opposed to power, which is just there to run something. The
three wires going to your amp module (BCLK, LRC, DIN — explained in Part
3) are all signal wires, not power wires — they carry rapidly changing
audio data, not steady power.

### Pull-up (mentioned for completeness)

A pull-up resistor is a small resistor that gently holds a pin at a known
voltage (usually 3.3V) when nothing else is actively driving it, so a
floating/undefined input doesn't produce random, meaningless readings. You
won't need to add one yourself in this build — the board's internal
circuitry and firmware settings already handle this for the touch pin and
any button — but it's worth knowing the term since it may come up if
something behaves inconsistently.

### Microcontroller, firmware, code

A **microcontroller** is the small computer chip on the board (inside the
XIAO). **Firmware** is the specific program that runs directly on a
microcontroller — as opposed to an app on your phone or a program on your
laptop, firmware runs with no operating system, directly on the bare chip.
"Code" and "firmware" are used interchangeably here. You don't need to
write any of it — it already exists in the repo — but you do need to
*send* it to the board, which is called **flashing** or **uploading**.

### Serial communication / USB

**Serial communication** means sending information one bit at a time over
a wire, in order — as opposed to sending many bits at once side-by-side.
It's the standard way small microcontrollers "talk" back to a computer.
When you plug the board into your laptop with a **USB** cable, two things
happen over that same cable: (1) power is supplied to the board, and (2) a
serial communication channel opens, letting your laptop send the firmware
to the board, and letting the board send text messages back to your laptop
(this is how you'll "hear" the board tell you what's working, via a window
called the **Serial Monitor**).

### Multimeter (full explanation in Part 4 — flagging it here since it's used constantly)

A handheld tool with two probes that measures voltage, resistance, and
continuity (whether two points are electrically connected). This is your
main testing instrument for everything before you write or run any code.

### Breadboard (not really used in this build, mentioned for completeness)

A breadboard is a reusable plastic board with holes for temporarily
plugging in components and wires without soldering, for prototyping. Your
build appears to be a mix of permanent solder joints and some push-on
jumper-wire connections directly onto the board — no breadboard is
involved. If you ever do see one in this project, treat it as a temporary
bench-test rig, not part of the final wearable.

---

## Part 2 — Wiring reference table

This is drawn directly from your teammate's own wiring documentation
(`wiring_guide.html`, `solder_card.html`) and cross-checked against the
actual firmware pin definitions in `firmware/src/pins.h`. All three sources
agree with each other, which is a good sign — but **none of them is a
photo of the real board**, so before you rely on this, do the physical
verification described in Stage 1.

**Important labeling gotcha, stated up front:** the tiny text printed on
the board next to each pin (the "silkscreen," e.g. `D8`) is *not* the same
number as the GPIO number used in the code (e.g. `GPIO 7`). They refer to
the same physical pin, but by two different naming systems. Always wire
and verify by the **printed pad label** on the board, since that's what
your eyes can actually check.

| From (board pad, printed label) | GPIO number (used in code) | To | Wire colour (per docs) | Purpose | What it carries | Check |
|---|---|---|---|---|---|---|
| `3V3` | — (power pin, no GPIO number) | Amp `VIN` | Red | Powers the amp | Steady 3.3V power | Confirm it's `3V3`, not the nearby `5V` pin |
| `GND` | — (ground pin) | Amp `GND` | Black | Shared ground / return path | 0V reference | Must be connected — nothing works without this |
| `D8` | `GPIO 7` | Amp `BCLK` (also labeled `SCK` on some amps) | Yellow | I2S bit clock — timing pulse for the audio data | Rapidly pulsing digital signal | Not power — should read as a signal, not a steady voltage |
| `D9` | `GPIO 8` | Amp `LRC` (also labeled `WS`) | Green | I2S word select — tells the amp left vs. right audio channel | Digital signal | — |
| `D10` | `GPIO 9` | Amp `DIN` | Blue | I2S data — the actual audio samples | Digital signal | — |
| `D2` | `GPIO 3` | Touch disc (coin/screw head) in front pod lid | White | Touch-sense input | Capacitive sensing signal | This is the *only* pin using this jack of wires — it does not connect to the amp at all |
| Amp `OUT+` / `OUT−` | — | Speaker's two terminals | (typically 2 unmarked wires) | Delivers amplified audio to the speaker | Amplified analog audio | Polarity does **not** matter here — a single speaker has no "wrong way round" |

**I2S**, mentioned above, is just the name of the standard these three
signal wires (BCLK/LRC/DIN) together implement for sending digital audio
between two chips. You don't need to understand how it works internally —
just that these three wires are a matched set and none of them carries
power.

**What is deliberately NOT connected, and should stay that way:**
- The board's `5V` pin — not used in this design.
- The board's `D0`, `D1`, `D3`(as touch, that's `D2`)... — i.e. any pad not
  in the table above should have nothing wired to it.
- On the amp module, any pins labeled `GAIN`, `SD`, or `SHUTDOWN` — these
  should be left completely empty. Connecting `SD`/`SHUTDOWN` to ground
  will silence the amp entirely, which looks exactly like a wiring fault
  but isn't one.

### How to physically identify things on the board

- **The board** is the smaller of the two boxes' main components — a green
  or blue rectangular circuit board roughly the size of a large postage
  stamp, with a USB-C socket (a small silver slot) at one end.
- **Pads/pins** are small silver-coloured rectangles along both long edges
  of the board, each with a tiny letter/number printed next to it. With
  the USB socket pointed away from you, one edge reads (top to bottom)
  `D0 D1 D2 D3 D4 D5 D6`, and the other reads `5V GND 3V3 D10 D9 D8 D7`.
  Use your phone's camera zoomed in if the print is too small to read.
- **Positive vs. negative / power vs. ground:** on this specific board,
  there's no ambiguity to resolve — the pins are individually labeled
  `3V3`, `5V`, and `GND` directly, rather than using generic + / − marks.
  Wire by the printed label, not by wire colour (wire colours in the docs
  are a convention your teammate chose, not something enforced by the
  hardware itself).
- **The camera** connects via a short, flat ribbon cable into a small
  black clip connector — you should NOT need to touch this unless it's
  come loose (see Stage 1).
- **The amp module** is a separate small board with its own pin labels
  printed on it (`VIN`, `GND`, `BCLK`/`SCK`, `LRC`/`WS`, `DIN`, and
  possibly `GAIN`/`SD`). Exact label wording can vary by manufacturer —
  the wiring guide already lists the common alternate names above.

### Where this could still be ambiguous — verify yourself

I don't have a photo of the actual soldered board, so I can't confirm:
- Which physical wire colour was actually used for which signal (your
  teammate may not have had all six specified colours available).
- Whether every connection was soldered directly to the pad, or whether
  some use small push-on jumper connectors.
- The exact model/brand of amp module, and therefore its exact pin
  labeling.

**Before Stage 1**, take a clear, well-lit photo of both pods with the
lids off, and compare what you see against the table above by *label*,
not colour. If a wire colour doesn't match what's in the table, that's not
automatically wrong — just note it and confirm where each wire actually
starts and ends by tracing it with your eyes (or the continuity test in
Stage 2, which is the reliable way to know for certain).

---

## Part 3 — Multimeter, taught from scratch

### What it is

A multimeter is a handheld box with a dial (or buttons) to select a mode,
a small screen, and two thin cables ending in metal probe tips — one red,
one black. It measures electrical properties by touching the two probe
tips to two points in a circuit.

### The two probe sockets

Most multimeters have 2–3 sockets to plug the probes into. For everything
in this guide, you only need:
- **Black probe → socket labeled `COM`** (common/ground reference).
  Always plug it here.
- **Red probe → socket labeled `V Ω mA` or similar** (the standard socket
  for voltage, resistance, and continuity). There is sometimes a
  *separate* socket for measuring large current, often labeled `10A` — you
  will **never** use that socket in this guide. Measuring current requires
  breaking open the circuit and putting the meter directly in the current
  path, which risks a short if done wrong, and this build doesn't need it.
  If your red probe is ever plugged into a current socket, unplug it and
  move it back to `V Ω mA` before doing anything else.

### The modes you need

Turn the dial (or press mode button) to select:

1. **Continuity mode** — usually shown as a small sound-wave symbol `)))`
   or a diode symbol. This mode makes the meter beep if the two probes are
   electrically connected to each other (even through a long path of
   wire), and stay silent if they are not. **This is your main tool for
   almost this entire guide.**
2. **DC Voltage mode** — usually shown as `V` with a straight/dashed line
   (as opposed to `V` with a wavy line, which is AC voltage — not used
   here). Set the range to something like 20V if your meter is manual
   range (auto-ranging meters handle this themselves). This measures the
   voltage *difference* between two points, without breaking the circuit
   open — you just touch both probes to two points while the circuit is
   powered.
3. **Resistance mode (Ω)** — you likely won't need this directly, since
   continuity mode already tells you what you need for this project, but
   it's the same probe setup as continuity.

### The critical difference: voltage vs. current measurement

- **Measuring voltage** = touching both probes to two points *without*
  cutting or opening the circuit. The meter sits "alongside" the circuit,
  sipping a tiny bit of current to sense the voltage, and doesn't disturb
  anything. This is safe to do on a powered circuit, and it's what you'll
  do in Stage 3.
- **Measuring current** = requires breaking the circuit open and forcing
  ALL the current to flow *through* the meter itself, in series. If you
  ever did this by mistake — e.g. by setting the dial to a current mode
  and then touching the probes across two points like you would for
  voltage — you create a short circuit through the meter, which can blow
  a fuse in the meter at best, and damage your board at worst.
  **You will not need to measure current anywhere in this guide.** I'm
  flagging this so that if you ever see a current-related mode on your
  dial (often marked `A` or `mA`), you know to avoid it here.

### Continuity testing — step by step

This must always be done with **the circuit completely powered off** (USB
unplugged). Testing continuity on a powered circuit can give misleading
readings and, more importantly, some meters can be damaged by voltage
present in continuity mode.

1. Set the dial to continuity mode (`)))`).
2. Touch the two probe tips together, away from the circuit. You should
   hear a beep and see a reading near `0` (near-zero resistance, since
   the probes are directly touching). This confirms the meter and its
   battery are working. If you don't hear a beep here, replace the
   meter's battery before continuing.
3. To test whether two specific points in your build are connected, touch
   one probe to each point (order doesn't matter — continuity has no
   "direction"). **Beep = connected. Silence = not connected.**

### Voltage testing — step by step

Done with the circuit **powered on** (USB plugged in).

1. Set the dial to DC Voltage, appropriate range (20V range is fine for a
   3.3V circuit; auto-ranging meters just need "V DC" selected).
2. Touch the **black** probe to a GND point, and the **red** probe to the
   point you want to measure — e.g. the `3V3` pad, or the amp's `VIN` pin.
3. Read the number on the screen. If you get a negative number, it just
   means you have the probes reversed relative to how the meter defines
   positive — swap them, or just note the number's absolute value; it
   won't harm anything to have them "backwards" for a voltage reading.

---

## The staged testing procedure

Do these in order. Do not skip ahead to a later stage until the current
one passes.

---

### Stage 0 — Understand the system (done)

You've now read Parts 0–3 above. Before continuing, you should be able to
answer, in your own words: what does the board do, what does the amp do,
what does the touch pad do, and what does GND mean. If any of those still
feel shaky, re-read the relevant section above before continuing — the
rest of this guide assumes it.

---

### Stage 1 — Power-OFF visual inspection

**What we're doing:** looking at the physical build with your eyes (and a
magnifier/phone camera if needed), with zero power applied, to catch
obvious problems before they can cause any electrical damage.

**Why:** this catches the highest-value, lowest-effort class of problems —
loose connections, a wire on the wrong pad, a solder joint that's clearly
"cold" (dull and lumpy rather than shiny) — before you risk anything by
applying power. Skipping this and going straight to power-on means you
find these same problems the hard way, potentially after damage is done.

**Exact steps:**

1. Confirm the USB cable is fully unplugged from the board. Set it aside.
2. Open both pods (front and rear) so you can see the internals. If
   they're glued shut, stop and check with your teammate before forcing
   anything open.
3. Using the wiring table in Part 2, visually trace each of the six wires
   from its labeled pad on the board to its destination. For each one,
   confirm:
   - It's actually touching the pad it should be soldered/connected to
     (not just resting nearby).
   - The wire isn't touching any *other* pad or exposed metal it
     shouldn't be (this is what a short circuit looks like physically —
     two bits of bare metal touching that shouldn't be).
   - If soldered: the joint looks like a small **shiny, smooth** dome. A
     **dull, grey, or lumpy** joint may not be making a proper connection.
   - Gently (not forcefully) tug each wire. It should not move or pull
     free.
4. Check the camera ribbon is fully seated in its connector, with the
   small black latch pressed flat/closed (not sticking up).
5. Look specifically along the row of solder joints *from the side*, at
   table height, rather than from above. A bridge (blob of solder
   accidentally joining two adjacent pads) is often invisible from above
   but obvious from the side.

**Expected result:** every wire goes where the table says, joints look
shiny and solid, nothing wiggles, no two pads are touching each other.

**What a pass tells you:** the wiring is *probably* correct — but "looks
right" isn't proof of an actual electrical connection (a joint can look
fine and still not conduct — "dry joint"), which is exactly why Stage 2
exists.

**If you find a problem:** don't try to fix soldering yourself unless you
already know how — flag it to your teammate. Do not proceed to Stage 2
with a wire touching a pad it shouldn't be near, since that's the specific
short-circuit condition Stage 2's checks are designed to catch, and it's
safer to already know about it.

**Safety check before moving on:** USB still unplugged? Good, continue.

---

### Stage 2 — Continuity checks (multimeter, power OFF)

**What we're doing:** using the multimeter's continuity mode (see Part 3)
to electrically *prove* two things: (a) there is no short circuit between
power and ground, and (b) every intended connection actually conducts.

**Why:** this is the single most important safety gate in this whole
process. A short between `3V3` and `GND` can destroy the board the instant
you apply power — with no warning, no smell, sometimes no visible sign at
all until it simply doesn't turn on again. This check costs about two
minutes and catches it before any power is involved.

**Confirm before starting:** USB unplugged. Multimeter set to continuity
mode (`)))`), probes touched together to confirm a beep (see Part 3).

**Step 2a — the four checks that MUST be silent (no beep):**

| Touch probe 1 to | Touch probe 2 to | Expected |
|---|---|---|
| `3V3` pad | `GND` pad | **Silence.** A beep here means a short — stop, do not power on. |
| `D8` pad | `D9` pad | Silence |
| `D9` pad | `D10` pad | Silence |
| `D10` pad | `3V3` pad | Silence |

Each of these pairs is a *neighbouring* pad on the board — the classic way
an accidental solder bridge forms. If any of these beep, there's a bridge
of solder joining two pads that shouldn't be joined. This must be found
and fixed before you go any further — see the troubleshooting tree at the
end of this guide.

**Step 2b — the checks that SHOULD beep (this proves the wire actually works):**

For each of the six wires in the Part 2 table, touch one probe to the pad
on the board, and the other probe to the *far end* of that same wire
(e.g., at the amp's corresponding pin). This proves current can actually
flow along that specific wire — a joint can look perfect and still not
conduct (a "dry" or "cold" joint).

| Board pad | Far end to touch | Expected |
|---|---|---|
| `3V3` | Amp `VIN` | **Beep** |
| `GND` | Amp `GND` | **Beep** |
| `D8` | Amp `BCLK`/`SCK` | **Beep** |
| `D9` | Amp `LRC`/`WS` | **Beep** |
| `D10` | Amp `DIN` | **Beep** |
| `D2` | Touch disc | **Beep** |

**What a full pass means:** no shorts, and every intended wire actually
conducts end to end. This is the point where it becomes reasonably safe to
apply power for the first time.

**If step 2a finds a beep (a short):** **Do not proceed to power-on.**
Go to the "Bridge found" branch of the troubleshooting tree at the end of
this document.

**If step 2b finds silence where you expected a beep:** that specific wire
isn't making a connection somewhere along its length — a cold joint, a
loose push-on connector, or a broken wire. Note which one, and fix that
specific joint (or have your teammate do it) before continuing. Don't
apply power with a known-broken signal wire; it won't cause damage, but
you'll waste time debugging what looks like a software problem later when
it's actually this.

**Safety check before moving on:** all four "must be silent" checks passed
silent, and all six "should beep" checks beeped? Then, and only then,
continue to Stage 3.

---

### Stage 3 — Power supply verification (multimeter, power ON)

**What we're doing:** plugging in USB for the first time, and immediately
using the multimeter in voltage mode to confirm the board is actually
producing the 3.3V it's supposed to, before trusting it to run anything.

**Why:** Stage 2 proved the wiring is safe (no shorts). This stage proves
the power itself is actually correct — it's possible for a board to power
up but for something to be subtly wrong (a bad USB cable delivering
insufficient power, for example) that voltage measurement catches and a
visual check wouldn't.

**Exact steps:**

1. Set the multimeter to DC Voltage mode.
2. Plug the USB cable into the board and into your laptop (or a USB power
   brick).
3. **Within the first 5 seconds**, gently touch the board and the amp
   module with a fingertip (a quick dab, not holding it there). Both
   should feel cool or barely warm. **If anything feels distinctly warm
   or hot, unplug the USB cable immediately** and return to Stage 2 — this
   means there's a short that Stage 2 didn't catch (possibly something
   that only shorts once power is flowing, such as a wire that's *just*
   touching another pad under slight pressure).
4. If nothing is warm, look for a small LED on the board lighting up —
   this is a basic "it's receiving power" indicator.
5. Now measure: black probe on `GND`, red probe on `3V3`. Expected
   reading: **approximately 3.3V** (anywhere roughly 3.0–3.4V is normal).
6. Measure black probe on `GND`, red probe on amp `VIN`. Expected: also
   approximately 3.3V — since it's wired directly to the board's `3V3`
   pin, it should read the same.

**What a pass means:** the board is correctly powered, and that power is
correctly reaching the amp. You're now safe to move on to actually running
software.

**If you measure 0V or something far from 3.3V:** stop and go to the
troubleshooting tree ("No power reading" branch).

**If nothing lit up and the board seems completely dead:** try a different
USB cable first — a very common failure mode is a "charge-only" cable that
supplies power but has no data wires, or in rare cases a cable that
carries neither properly. Confirmed by trying a cable you know works with
another device.

---

### Stage 4 — Software/firmware setup (from scratch)

**What software/firmware is, again, in context:** your board doesn't do
anything on its own — it needs a program loaded onto it. Right now (fresh
from soldering) it very likely has no program on it at all, or an
unrelated factory-test program. You're going to install a program on your
laptop that can *build* the firmware code from the repo into a form the
board understands, and *send* it over the USB cable onto the board's
internal memory. This process is called **flashing** or **uploading**.

**Tool you need: PlatformIO** (a free extension for a program called VS
Code). VS Code is a text editor; PlatformIO is what teaches it how to talk
to microcontroller boards like yours.

**Setup steps:**

1. Download and install VS Code from `code.visualstudio.com`.
2. Open VS Code. Click the Extensions icon in the left sidebar (looks like
   four small squares, one pulled away from the rest) — or press
   `Ctrl+Shift+X` (`Cmd+Shift+X` on Mac).
3. Search for `PlatformIO IDE`, click Install. This takes several minutes
   the first time — let it finish uninterrupted.
4. Restart VS Code when prompted. You should now see a small toolbar
   along the very bottom edge of the window (a checkmark, a right-arrow,
   and a plug icon) — this is the PlatformIO build toolbar, and you'll use
   these three icons repeatedly.
5. In VS Code: `File → Open Folder`, and select the **`firmware`** folder
   specifically (not the parent repo folder — PlatformIO looks for a file
   called `platformio.ini`, which lives directly inside `firmware/`).
6. Wait for the bottom bar to finish "configuring" (first time only — it's
   downloading additional tools for this specific board). Several minutes.

**How your laptop identifies the board (the USB/serial port):**

Every device plugged into USB gets assigned an identifier by your
computer — on a Mac this looks like `/dev/cu.usbmodem1101`, on Windows
it's something like `COM5`. You don't need to memorize this, but it's
useful to understand what you're looking at when you see it. To check:

- Click the PlatformIO (alien head) icon in the left sidebar → "Devices"
  under PIO Home. You should see one entry appear/disappear when you
  plug/unplug the board — that's how you confirm you're looking at the
  right one, if more than one device is listed.

**Copying the secrets file:** the firmware needs your WiFi name/password
and your laptop's network address, kept in a file that's deliberately kept
out of the shared repo (so passwords don't get committed to GitHub).

1. In VS Code's file panel, find `src/secrets.h.example` inside `firmware`.
2. Copy it, paste it, and rename the copy to exactly `secrets.h` (same
   folder).
3. Open `secrets.h` and fill in your WiFi network name and password. You
   can leave the server address blank for now — it's not needed for the
   hardware self-test in the next stage.
4. **Important:** the ESP32S3 board only supports **2.4GHz WiFi**, not
   5GHz. If your home network is 5GHz-only, this will silently never
   connect — check your router settings if this comes up later.

---

### Stage 5 — Power-on test using the dedicated diagnostic program

This is the heart of the whole guide. Your teammate's repo already
contains a purpose-built diagnostic program (`selftest.cpp`) whose entire
job is exactly what you're trying to do: check each piece of hardware,
one at a time, in a safe order, and report PASS/FAIL in plain English.
Use this instead of the "real" firmware for all testing — the real
firmware (`main.cpp`) assumes everything already works, which makes it a
much worse tool for finding out whether that's true.

**What "uploading" and "the serial monitor" mean, concretely:**

- **Uploading** = clicking the right-arrow icon in the bottom toolbar.
  PlatformIO converts the code into a form the chip understands and sends
  it over USB. You'll see a wall of text scroll by, ending in `SUCCESS` (or
  a red error, which is not success).
- **Serial Monitor** = a window that shows text messages the board sends
  back to your laptop while it's running. This is how the diagnostic
  program tells you what it found. Open it by clicking the plug icon 🔌
  in the bottom toolbar.

**Exact steps:**

1. At the very bottom of VS Code, click where it shows the current
   "environment" name (near the alien-head icon). Select **`selftest`**
   from the menu (as opposed to the default environment, which builds the
   real firmware). This matters — building the wrong one either won't run
   the diagnostics, or will collide, since both programs can't run at
   once.
2. Click the checkmark icon (Build) first, just to confirm it compiles
   without errors.
3. Click the right-arrow icon (Upload). Wait for `SUCCESS`.
   - If it says it can't find the port: hold the **BOOT** button on the
     board, tap **RESET**, release BOOT, then click Upload again. (These
     are two small physical buttons on the board itself.)
4. Click the plug icon (Serial Monitor).
5. Press the **RESET** button on the board (the test runs automatically
   on boot, so you may need to reset to see it from the very start).
6. Read the output. It will run through, in this order, and this order is
   deliberate — **the first failure in the list is the one to actually
   fix; everything below it may just be a knock-on symptom, not a
   separate problem**:

   **a. PSRAM check.** PSRAM is a chunk of extra memory the camera needs
   to store a photo temporarily. This must PASS before the camera can
   possibly work — if PSRAM fails, that's a board configuration setting,
   not a wiring problem, and it needs fixing before camera testing means
   anything.

   **b. Camera check.** Confirms the camera initializes and can actually
   capture a frame of a sensible size (a failure here after PSRAM passed
   usually points at the ribbon cable connector, per Stage 1).

   **c. Touch pad calibration (interactive).** The program prints a
   baseline reading with nothing touching the pad, then asks you to hold
   your finger on the coin/screw-head for about 8 seconds while it streams
   live numbers. **Do this — don't skip it.** It will tell you the exact
   two settings your build needs (`TOUCH_ACTIVE_HIGH` and
   `TOUCH_THRESHOLD`) based on your *actual* physical pad, glue, and wire
   — these vary from build to build and cannot be reliably guessed or
   copied from someone else's numbers.

   **d. Audio test.** Plays a plain, clean 440Hz tone (a musical note,
   "A") directly through the amp and speaker — no file decoding involved,
   so if you hear it, the entire audio wiring chain (all three signal
   wires plus power) is proven correct, independent of anything
   software-related later.

   **e. WiFi test.** Confirms the board can join your network using the
   credentials from `secrets.h`.

   **f. Server reachability test.** Only relevant once you're running the
   `server/` program on your laptop (see Stage 6b) — it will report
   "skipped" if WiFi isn't connected, which is expected and fine at this
   point.

7. At the end, it prints a summary count and, if anything failed, a
   numbered list of what to fix, in the correct order.

**What to do with each individual result — decision tree:**

- **PSRAM: FAIL** → This is a board settings issue (`OPI PSRAM` needs to
  be enabled in the build configuration), not a soldering problem. This
  should already be set correctly in the repo's `platformio.ini` — if it
  still fails, this is a "flag to your teammate / check the repo file
  itself" situation rather than something to re-solder.
- **Camera: FAIL, PSRAM passed** → Power off, re-check the camera ribbon
  cable is fully seated with the latch closed flat (Stage 1, step 4).
  Re-test.
- **Touch: readings barely move when you touch it** → the white wire
  likely isn't making contact with the metal disc. Check that specific
  solder joint (Stage 1 and Stage 2 already tested D2-to-disc continuity
  — if that passed but this still fails, the disc's *surface* itself may
  need to be scuffed with sandpaper, since solder and capacitive sensing
  both need a clean electrical contact to the actual conductive surface a
  finger will touch).
- **Audio: I2S output failed to start** → power off, re-check `D8`, `D9`,
  `D10` connections from Stage 2 (this shouldn't happen if those all
  passed continuity, but re-verify nothing shifted).
- **Audio: "Tone played" passed but you heard nothing** →
  - Check whether the amp's `SD`/`SHUTDOWN` pin has accidentally been
    connected to GND (should be completely unconnected — see Part 2).
  - Measure amp `VIN` to `GND` with the meter (Stage 3 method) — expect
    ~3.3V. If you read 0V here even though the board's own `3V3` read
    correctly in Stage 3, the red wire between them has failed since
    Stage 2 (re-check that specific joint).
  - Confirm the speaker's two wires are actually connected to the amp's
    output terminals.
- **Audio: loud static/buzzing instead of a clean tone** → `BCLK` and
  `LRC` (yellow and green wires) are very likely swapped. Power off,
  swap them, re-test.
- **WiFi: FAIL** → double-check the WiFi name/password in `secrets.h`,
  and confirm the network is 2.4GHz (see Stage 4).

**Safety note for this whole stage:** every time you make a physical
change to the wiring based on a failure above, **unplug USB first**, make
the change, then re-run Stage 2's relevant continuity check before
re-powering — don't just re-plug in and hope. This keeps you from ever
powering a circuit you've just changed without having re-verified it.

---

### Stage 6 — Test communication with the software side

**6a. What's already been tested:** WiFi and (if applicable) server
reachability were already part of the `selftest` run in Stage 5. If those
passed, the board can talk to your laptop's network successfully.

**6b. Testing the actual AI server (optional at this stage, but useful
context):** the `server/` folder contains a separate program that runs on
your laptop (not the board) and does the "AI reads the label" part. You
can prove this half of the project works completely independently of any
hardware, using a tool called `curl` (a command that sends a file to a
web address from a terminal window):

```
cd server
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Then, in a second terminal window, with a photo of a label saved as
`box.jpg` in that same folder:

```
curl -X POST http://localhost:8000/read_label -F "image=@box.jpg"
```

If this returns a description of the label, the entire non-hardware half
of the project is proven to work, and any remaining problems are
definitely hardware/wiring, not the AI logic. This is a genuinely useful
diagnostic even before your hardware is fully working, because it narrows
down where a problem could possibly be.

---

### Stage 7 — Full system test

Only attempt this once every check in Stage 5 has passed.

1. Switch the PlatformIO environment (bottom toolbar) from `selftest`
   back to the real one (`seeed_xiao_esp32s3`).
2. Fill in the server address (`SERVER_HOST`) in `secrets.h` — find your
   laptop's local network address by running `ipconfig getifaddr en0`
   (Mac), `ipconfig` and reading the IPv4 address (Windows), or
   `hostname -I` (Linux).
3. Make sure the `server/` program (Stage 6b) is running in a terminal.
4. Upload the real firmware, open the Serial Monitor, and press RESET.
   Expect to see `WiFi connected` then `Glasses ready`.
5. Touch the pad (or press the button). Watch for: the board printing
   that it triggered, the server's terminal logging a request arriving,
   and — the actual product working — the speaker reading back whatever
   the camera is pointed at.
6. Repeat this ten times with different objects. Count failures. Anything
   less than ten clean successes is a reliability issue to chase down
   before demo night, not a hardware pass/fail question at this point.

---

## Troubleshooting decision tree (summary)

```
Multimeter beeps on 3V3–GND (Stage 2)?
  → STOP. Do not power on.
  → Look along the solder joints from the side (Stage 1, step 5) for a
    bridge of solder connecting two pads.
  → Clean the iron tip, drag it firmly across the bridge, away off the
    edge of the board. Re-test continuity. Repeat until silent.

A wire fails its "should beep" continuity check (Stage 2)?
  → That joint isn't conducting even though it may look fine.
  → Re-heat that specific joint until it flows, hold still 3 seconds while
    it cools, re-test.

Board/amp feels warm within 5 seconds of power-on (Stage 3)?
  → Unplug immediately.
  → Return to Stage 2 continuity checks — something is shorting only
    under load/pressure that a static check might have missed.

3V3 pad reads far from 3.3V, or 0V (Stage 3)?
  → Try a different USB cable (many are charge-only, no data).
  → If still 0V, this points to a board power-regulation fault — flag to
    your teammate rather than continuing to test downstream components.

selftest: PSRAM fails?
  → Configuration issue (OPI PSRAM setting), not a wiring problem.
  → Confirm platformio.ini hasn't been edited; otherwise flag it upstream.

selftest: Camera fails, PSRAM passed?
  → Power off. Re-seat the camera ribbon, confirm the latch is fully
    closed flat. Re-test.

selftest: Touch barely moves between untouched/touched readings?
  → Confirm D2–disc continuity (Stage 2) still passes.
  → If it does, the disc's surface likely needs scuffing (sandpaper) so
    solder — and a finger — make proper contact.

selftest: "Tone played" = PASS but you hear nothing?
  → Check amp SD/SHUTDOWN pin is completely unconnected.
  → Meter amp VIN–GND: expect ~3.3V. If 0V, re-check the red wire joint.
  → Confirm speaker leads are actually on the amp's output terminals.

selftest: static/buzzing instead of a clean tone?
  → BCLK and LRC (yellow/green) are almost certainly swapped.
  → Power off, swap them, re-test.

selftest: WiFi fails?
  → Check secrets.h credentials.
  → Confirm the network is 2.4GHz, not 5GHz-only.
```

---

## Final testing checklist

Print this or keep it open next to you. Do not check off a box until
you've actually done that step and gotten the expected result.

**Before any power:**
- [ ] Photographed both pods, lids off, good lighting
- [ ] Every wire in Part 2's table visually traced and matches (or
      discrepancies noted and understood)
- [ ] No two pads touching that shouldn't be
- [ ] All solder joints look shiny/smooth, not dull/lumpy
- [ ] Every wire gently tugged, none move
- [ ] Camera ribbon fully seated, latch closed flat

**Continuity checks (multimeter, power still OFF):**
- [ ] `3V3`–`GND`: silent
- [ ] `D8`–`D9`: silent
- [ ] `D9`–`D10`: silent
- [ ] `D10`–`3V3`: silent
- [ ] `3V3` → amp `VIN`: beeps
- [ ] `GND` → amp `GND`: beeps
- [ ] `D8` → amp `BCLK`: beeps
- [ ] `D9` → amp `LRC`: beeps
- [ ] `D10` → amp `DIN`: beeps
- [ ] `D2` → touch disc: beeps

**First power-on:**
- [ ] USB plugged in, board/amp checked for warmth in first 5 seconds — cool
- [ ] Board LED lit
- [ ] `3V3` measures ~3.3V
- [ ] Amp `VIN` measures ~3.3V

**Software setup:**
- [ ] VS Code + PlatformIO installed
- [ ] `firmware` folder opened directly (not the repo root)
- [ ] `secrets.h` created from the example, WiFi filled in

**selftest diagnostic run:**
- [ ] PSRAM: PASS
- [ ] Camera init: PASS
- [ ] Camera capture: PASS (reasonable byte size, not near-zero)
- [ ] Touch calibration run, `TOUCH_THRESHOLD`/`TOUCH_ACTIVE_HIGH` noted
      and written into `pins.h`
- [ ] Audio: I2S output started
- [ ] Audio: tone actually heard through the speaker
- [ ] WiFi: connected

**Full system:**
- [ ] Real firmware flashed, `SERVER_HOST` set
- [ ] Server running on laptop (`uvicorn ...`)
- [ ] Touch → capture → server log → spoken reply, confirmed once
- [ ] Repeated 10x, failure count noted

You're done with hardware/wiring verification once every box above is
checked. Anything that fails past this point is very likely a software,
network, or AI-prompt issue rather than a wiring one — worth knowing,
since it changes who on the team should look at it next.
