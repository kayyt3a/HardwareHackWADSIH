//-- Updated: 2026-08-24 21:06
//----------------------------------------------------------------
//-- LED blink - the simplest sketch that proves the board runs your code
//--
//-- Two LEDs take turns: the little orange one on the board, and one you
//-- plug into pad D10. While one is lit the other is dark, swapping once
//-- a second. No libraries, no wiring beyond the one LED - and even with
//-- nothing plugged in at all, the onboard LED alone shows it working.
//--
//-- WIRING - one LED to the XIAO ESP32S3 Sense:
//--   pad D10 -> resistor (220R to 1k) -> LED long leg (anode)
//--   LED short leg (flat side of the rim) -> GND pad
//-- The resistor is not optional. A pad is rated for about 20mA and an
//-- LED with nothing limiting the current will pull more, damaging the
//-- pad quietly rather than blowing the LED.
//--
//-- WHAT YOU SHOULD SEE
//-- The two LEDs alternate like a level crossing: onboard on / yours off,
//-- then the swap, forever. Open Tools > Serial Monitor at 115200 baud to
//-- see a line printed at each swap.
//--
//-- WHY ALTERNATE, NOT TOGETHER
//-- If both blinked together, a dead external LED would be hard to spot
//-- next to the working onboard one. Out of phase, "onboard blinks, mine
//-- never lights" is unmissable - and it means your LED is backwards or
//-- unpowered, not that the sketch is broken.
//--
//-- ONE TRAP: the onboard LED is ACTIVE LOW. Its other leg sits on 3.3V
//-- and the pin sinks the current, so LOW lights it and HIGH puts it out -
//-- backwards from what you'd guess. The two helper functions below hide
//-- that, so the rest of the code can say on and mean on.
//----------------------------------------------------------------
#include <Arduino.h>

// The XIAO ESP32S3 variant defines LED_BUILTIN as 21. Spelled out anyway so
// the sketch still builds on a board that doesn't.
#ifndef LED_BUILTIN
#define LED_BUILTIN 21
#endif

// The pads printed on the board (D0, D1...) are not the numbers the chip
// uses inside (GPIO numbers), and the code needs the GPIO number.
// Pad D10 is GPIO 9.
#define EXT_LED_PIN 9  // pad D10

#define BLINK_MS 500  // how long each LED holds its turn

// Onboard LED, active low - true means lit.
static void ledOnboard(bool on) {
  digitalWrite(LED_BUILTIN, on ? LOW : HIGH);
}

// External LED, wired the ordinary way round - no inversion.
static void ledExternal(bool on) {
  digitalWrite(EXT_LED_PIN, on ? HIGH : LOW);
}

// setup() runs ONCE when the board powers on or resets.
void setup() {
  // Make both pins outputs and put them in a known state. A pin left as an
  // input floats, and a floating pad with an LED on it glows dimly at random.
  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(EXT_LED_PIN, OUTPUT);
  ledOnboard(false);
  ledExternal(false);

  // Start the serial connection to your computer, so the board can print
  // messages you can read in the Serial Monitor (at this same 115200 rate).
  Serial.begin(115200);
  delay(2000);  // the USB link needs a moment before prints get through
  Serial.println("=== led blink - onboard and D10 taking turns ===");
}

// loop() runs over and over, forever. Each pass is one full swap cycle.
void loop() {
  ledOnboard(true);   // onboard's turn...
  ledExternal(false);
  Serial.println("onboard lit");
  delay(BLINK_MS);

  ledOnboard(false);  // ...then yours.
  ledExternal(true);
  Serial.println("external lit (pad D10)");
  delay(BLINK_MS);
}

//-- TRY CHANGING
//--   BLINK_MS          -> 100 for frantic, 2000 for a slow lighthouse
//--   the two false/true pairs -> both true, and they blink together instead
//--   EXT_LED_PIN       -> 8 (pad D9) or 7 (pad D8) - move the wire too
//--   swap LOW and HIGH in ledOnboard() and watch the blink invert: that
//--     backwards-looking blink is what active-low means
