//-- Updated: 2026-08-24 22:59
//----------------------------------------------------------------
//-- Speaker - the simplest thing that makes a sound
//--
//-- Beeps twice a second, forever. Nothing to press, no WiFi - if you hear
//-- the two-note beep, every part of the audio chain works. If you don't,
//-- this folder's README.md has the symptom-by-symptom table.
//--
//-- HOW DIGITAL AUDIO WORKS (the one-paragraph version)
//-- Sound is a wave. To store it digitally you measure the wave's height
//-- thousands of times a second - each measurement is called a SAMPLE, and
//-- this sketch uses 16,000 samples per second. The board streams those
//-- numbers out over a three-wire digital connection called I2S to a DAC
//-- (digital-to-analogue converter), which turns numbers back into a
//-- wobbling voltage. That signal is too weak to move a speaker, so it goes
//-- through an amplifier first. Chain: board -> DAC -> amp -> speaker.
//-- This sketch makes its samples from scratch with the sine function -
//-- a pure sine wave is the "cleanest" sound there is, a smooth beep.
//--
//-- WIRING - DAC/amp module to the XIAO ESP32S3 Sense:
//--   BCK -> pad D8    "bit clock" - ticks once per bit of data
//--   LCK -> pad D9    "left/right clock" - says which ear this sample is for
//--   DIN -> pad D10   the audio data itself
//--   SCK -> GND       "master clock" - our DAC makes its own, so tie this low
//--   VCC -> 5V pad
//--   GND -> GND pad
//-- Then the analogue half:
//--   DAC line out (signal AND its ground) -> amp input
//--   speaker -> one amp channel's + and - terminals. Neither speaker wire
//--   goes to ground - this amp drives both sides.
//--
//-- WHAT YOU SHOULD HEAR
//-- A quick two-note "bip-bip" (low then high), a pause, and again - about
//-- once a second. The Serial Monitor (115200 baud) prints hints too.
//--
//-- IF YOU HEAR NOTHING
//-- Check the amp really has 5V, and that BCK/LCK/DIN are on the right pads
//-- and not swapped. Hiss or buzz instead of a clean beep usually means two
//-- of those three wires are swapped. Crackle that comes and goes when you
//-- wiggle wires is a bad solder joint on the analogue side.
//----------------------------------------------------------------
#include <Arduino.h>
#include <driver/i2s.h>  // the chip's built-in I2S (digital audio) driver
#include <math.h>        // for sinf(), the sine function

// The pads printed on the XIAO board (D8...) are not the numbers the chip
// uses inside (GPIO numbers) - the code needs the GPIO numbers.
#define SPK_BCLK 7  // pad D8
#define SPK_LRCK 8  // pad D9
#define SPK_DOUT 9  // pad D10

#define SAMPLE_RATE 16000  // samples per second
#define AMPLITUDE 0.4f     // volume, 0.0 to 1.0 - much above 0.4 starts to
                           // distort on this little amp, like a blown speaker

// Plays one smooth beep: a sine wave at the given pitch (hz), for the given
// time (ms). It calculates samples one at a time and hands them to the I2S
// driver, which streams them out to the DAC at exactly 16,000 per second.
void playTone(float hz, uint32_t ms) {
  // One "frame" is a left sample plus a right sample. We send the same
  // number to both, so the speaker works whichever channel it's wired to.
  static int16_t frame[2];
  const uint32_t total = SAMPLE_RATE * ms / 1000;  // how many samples to make
  float phase = 0.0f;  // where we are along the sine wave, in radians

  for (uint32_t i = 0; i < total; i++) {
    // sinf(phase) is between -1 and 1. Scale it by the volume, then by
    // 32767 - the biggest value a 16-bit sample can hold.
    int16_t s = (int16_t)(AMPLITUDE * 32767.0f * sinf(phase));

    // Step the phase forward. Higher pitch = bigger steps = the wave
    // wiggles faster. Wrap at a full circle so the number never overflows.
    phase += 2.0f * PI * hz / SAMPLE_RATE;
    if (phase > 2.0f * PI) phase -= 2.0f * PI;

    frame[0] = s;  // left ear
    frame[1] = s;  // right ear
    // Hand the frame to the driver. If its outgoing queue is full, this
    // waits - which is what paces the loop to exactly the sample rate.
    size_t written = 0;
    i2s_write(I2S_NUM_1, frame, sizeof(frame), &written, portMAX_DELAY);
  }
}

// setup() runs ONCE when the board powers on or resets.
void setup() {
  // Start the serial connection so the board can print messages to your
  // computer's Serial Monitor.
  Serial.begin(115200);
  delay(2000);  // the USB link needs a moment before prints get through
  Serial.println("=== speaker example - two beeps per second ===");

  // Describe the audio stream we want. This struct is a list of settings
  // handed to the driver in one go.
  i2s_config_t config = {};
  config.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);  // we send (TX) and we make the clocks (MASTER)
  config.sample_rate = SAMPLE_RATE;
  config.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;   // each sample is a 16-bit number
  config.channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT;   // stereo: left and right
  config.communication_format = I2S_COMM_FORMAT_STAND_I2S;
  config.intr_alloc_flags = ESP_INTR_FLAG_LEVEL1;
  config.dma_buf_count = 8;    // the driver keeps 8 buffers of...
  config.dma_buf_len = 256;    // ...256 frames each, feeding the DAC in the
                               // background while our code makes more samples
  config.tx_desc_auto_clear = true;  // if we ever fall behind, play silence
                                     // rather than repeating old samples as a buzz
  config.mclk_multiple = I2S_MCLK_MULTIPLE_256;  // bit-clock ratio, stated
                                     // rather than left implicit - the full
                                     // OttoFinder sets the same

  // Install the driver with those settings. Almost the only way this fails
  // is if something else already claimed I2S unit 1.
  if (i2s_driver_install(I2S_NUM_1, &config, 0, nullptr) != ESP_OK) {
    Serial.println("i2s driver install failed");
    while (true) delay(1000);  // sit here forever so the error stays visible
  }

  // Tell the driver which physical pins to use.
  i2s_pin_config_t pins = {};
  pins.mck_io_num = I2S_PIN_NO_CHANGE;  // master clock: SCK is wired to GND, not to us
  pins.bck_io_num = SPK_BCLK;
  pins.ws_io_num = SPK_LRCK;
  pins.data_out_num = SPK_DOUT;
  pins.data_in_num = I2S_PIN_NO_CHANGE;  // we only send, nothing comes back
  i2s_set_pin(I2S_NUM_1, &pins);

  // A freshly installed driver starts clocking out whatever its buffers happen
  // to hold, which off a cold boot is not silence. Zero them so the first
  // thing the DAC hears is the first beep, not a burst of noise.
  i2s_zero_dma_buffer(I2S_NUM_1);

  Serial.println("if you hear nothing: check the amp has 5V, and that BCK/LCK/DIN aren't swapped");
}

// loop() runs over and over, forever: two quick notes, then a pause.
void loop() {
  playTone(880, 100);   // the note A, 100 milliseconds
  playTone(1320, 100);  // the note E, a musical fifth higher
  delay(800);           // silence between beeps
}

//-- TRY CHANGING
//--   the frequencies  -> 262/330/392 is C-E-G, a major chord; below ~200Hz
//--                       this small speaker barely makes any sound
//--   the 100ms        -> 500 for long slow notes
//--   AMPLITUDE        -> 0.1 for quiet; listen for the harsh edge if you
//--                       push it past 0.5
//--   add more notes   -> a few more playTone() lines in loop() is a melody
