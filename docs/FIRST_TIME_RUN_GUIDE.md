# Running Vocalens for the first time

This is a start-to-finish guide for someone who has never done any of this
before — installing PlatformIO, starting the server, flashing the board, and
taking a first camera reading. Follow it in order.

## Before you start: two windows

You'll need two terminal/editor windows open side by side for the whole
session:

1. **A terminal window** — this runs the Python server (`uvicorn`). Leave it
   open the entire time; it's your main log of what the board is sending.
2. **A VS Code window with PlatformIO** — this is where you edit, build, and
   upload the firmware, and where the Serial Monitor lives.

Keep both visible if you can — when you take a photo later, you'll want to
watch both at once.

## Installing PlatformIO

1. Install [VS Code](https://code.visualstudio.com/) if you don't have it.
2. Open VS Code → Extensions (the icon on the left sidebar, or `Ctrl+Shift+X`).
3. Search for **"PlatformIO IDE"** and click Install.
4. Wait for it to finish (it installs its own Python environment in the
   background — this can take a few minutes the first time).
5. Restart VS Code when it asks you to.
6. **Important**: don't open the whole repo folder in VS Code. Open the
   `firmware` folder specifically (File → Open Folder → select `firmware`).
   PlatformIO only shows its toolbar (the row of icons at the very bottom of
   the window) when `platformio.ini` is at the top level of what's open — if
   you open the repo root instead, that toolbar won't appear and nothing
   will seem to work.

## 1. Starting the server

Run this from a fresh terminal, in the `server` folder.

```
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

(`.venv\Scripts\activate` is the Windows command — you should see `(.venv)`
appear at the start of your prompt once it's worked.)

You should see `Uvicorn running on http://0.0.0.0:8000` and nothing else —
leave this terminal open and running for the rest of the session. Every
request the board makes will show up here as a new log line, so keep an eye
on it.

### Problems that came up getting here, and how they were fixed

These are worth knowing in case you hit the same ones:

- **`pip install` fails trying to build Pillow or pydantic from source**
  (mentions `link.exe not found` or `maturin failed`) — this happens when
  the venv's Python is too new for the exact package versions pinned in
  `requirements.txt`. Already fixed in this repo's `requirements.txt`
  (`Pillow>=11.0.0`, `pydantic>=2.10.0`), so a fresh `pip install` shouldn't
  hit this — but if it does, those are the two lines to loosen.
- **`python -m venv .venv` — "Unable to create process...system cannot find
  the file specified"** — happened when trying to force a specific Python
  version (e.g. `py -3.13`) that wasn't actually installed properly. Fixed
  by just using plain `python -m venv .venv` and letting it use whatever
  version is on your PATH.
- **`pip install -r requirements.txt` → "Could not open requirements file"**
  — means your terminal isn't `cd`'d into the `server` folder yet. Run
  `cd server` first, and check with `dir` that `requirements.txt` is
  actually listed there.
- **Server crashes on startup with a `pyzbar`/`libzbar-64.dll not found`
  error** — this is the barcode-scanning library, and it's broken on some
  Windows setups. It's not needed for the main camera+question flow, and
  `server/main.py` already catches this error and disables barcode scanning
  gracefully instead of crashing — you should just see a warning logged, not
  a crash. If you ever see the server actually crash on this, it means that
  fix isn't in your copy of `main.py`.
- **The README mentions `.env.example` and `ANTHROPIC_API_KEY`/
  `OPENAI_API_KEY`** — this is out of date. All you actually need is one
  file, `server/.env`, containing a single line:
  ```
  OPENROUTER_API_KEY=your-key-here
  ```
  Every model call (vision, speech-to-text, text-to-speech) goes through
  OpenRouter now, so this one key is all that's required.

## 2. Using the secrets file

The firmware needs your WiFi details and your computer's IP address, kept in
a file that's never committed to git (so credentials don't leak).

1. In `firmware/src/`, find `secrets.h.example`.
2. Copy it and rename the copy to `secrets.h`, in the same folder.
3. Open `secrets.h` and fill in:
   ```
   #define WIFI_SSID "your-wifi-name"
   #define WIFI_PASSWORD "your-wifi-password"
   #define SERVER_HOST "192.168.x.x"
   #define SERVER_PORT 8000
   ```
4. To find `SERVER_HOST`: open a new terminal on the computer running the
   server and run `ipconfig`. Look under "Wireless LAN adapter Wi-Fi" for
   **IPv4 Address** — it'll look like `192.168.x.x` or `10.x.x.x`. That's
   the value to put in `SERVER_HOST`.

**This IP address changes** if you reconnect to WiFi or restart your
computer — if the board suddenly can't reach the server after a break,
re-check `ipconfig` and update `secrets.h` if it's changed.

If the board can't reach the server at all, also check that Windows
Firewall isn't blocking it — add an inbound allow rule for
`server\.venv\Scripts\python.exe` on Private networks.

## 3. Connecting and uploading via PlatformIO

1. Plug the board in via USB.
2. With the `firmware` folder open as your project root, look at the bottom
   status bar in VS Code — that's the PlatformIO toolbar.
3. Click the checkmark icon to **Build** — this compiles the code without
   uploading, so it's a fast way to check for errors first.
4. Click the right-arrow icon to **Upload** — this flashes the compiled code
   onto the board. Wait for `SUCCESS` in the terminal output at the bottom.
5. Click the plug icon to open the **Serial Monitor** — this is how the
   board talks back to you (115200 baud, already set as the project
   default). You should see boot messages, including `WiFi connected`.

By default this builds the real firmware (`main.cpp`). PlatformIO also has
two other environments in this project for testing individual parts in
isolation — click the environment name in the same toolbar to switch:
- `selftest` — full hardware diagnostic (see below)
- `beeptest` — makes the speaker beep once a second, for isolating
  speaker/amp wiring issues
- `ledblink` — blinks the onboard LED and one on pad D10, the simplest
  possible "does the board run my code at all" check

Switch back to the default environment before flashing the real firmware
again — only one of these can be compiled and running at a time.

## 4. Running the selftest

Use this to check PSRAM, camera, touch pad, I2S audio, WiFi, and server
reachability all in one go, before trying the full pipeline.

1. In the PlatformIO toolbar, switch the environment to `selftest`.
2. Build → Upload → open the Serial Monitor.
3. It runs through each check automatically and prints `PASS`/`FAIL` for
   each one, with notes if something failed.
4. Switch the environment back to the default (`seeed_xiao_esp32s3`) before
   flashing the real firmware again.

## 5. Running the camera test

This is the full bench-test flow: touch the coin, type a question, get a
text answer back, with a real photo taken along the way.

Make sure the server (step 1) is running and the board has been flashed
with the real firmware (not `selftest`) and shows `WiFi connected` in the
Serial Monitor first.

1. Open the **Serial Monitor** in PlatformIO if it isn't already open.
2. **Touch the coin.** An input box should appear at the top of the Serial
   Monitor panel.
3. Type your question into that input box (e.g. "what is this?") and press
   **Enter**. You have 15 seconds to do this before it falls back to a
   default question.
4. Wait for the answer. The board captures a photo and sends it to the
   server — both terminals should show activity:
   - The **server terminal** logs the incoming request and shows
     `Saved capture: ...jpg`.
   - The **PlatformIO Serial Monitor** prints the answer once it comes
     back, under a line that reads `===== ANSWER =====`.
5. **To see the actual photo**, look in `server/captures/` — every photo the
   board sends gets saved there automatically, named with a timestamp. Open
   the most recent one to see exactly what the board captured and sent.

## 6. Changing the model, image resolution and compression

### Changing the vision model

The model that answers questions about the photo is set in `server/.env`:

```
VISION_MODEL=minimax/minimax-m3:free
```

Change the value and restart `uvicorn` (`Ctrl+C` in the server terminal,
then run the `uvicorn` command again) to pick a different model — any
vision-capable model available on [OpenRouter](https://openrouter.ai/models)
will work, referenced by its OpenRouter model ID (the
`provider/model-name` format shown on its page there). If the line isn't in
`.env` at all, it just uses the default shown above.

Free-tier models (ID ends in `:free`) are the slowest and least accurate
option — they're what's being used now to avoid burning credits during
testing, but a paid model is the single biggest lever for both faster
answers and better accuracy, if you have credit available.

### Changing image resolution and compression

Both are set in `setupCamera()` in `firmware/src/main.cpp`:

```cpp
config.frame_size = FRAMESIZE_SXGA; // 1280x1024
config.jpeg_quality = 9;            // lower number = less compression
```

- **`frame_size`** controls resolution. Common options, smallest to
  largest: `FRAMESIZE_VGA` (640x480), `FRAMESIZE_SXGA` (1280x1024),
  `FRAMESIZE_UXGA` (1600x1200 — the largest this sensor supports). Higher
  resolution gives the vision model more detail to work with (useful for
  small print) but makes for a bigger file, which takes longer to upload
  over WiFi and adds to the overall response time.
- **`jpeg_quality`** controls compression, on a scale of roughly `0`–`63` —
  counterintuitively, a **lower** number means **less** compression and a
  **higher-quality** image (and a bigger file). `9` is fairly high quality;
  going up towards `20`+ trades detail for a smaller, faster-uploading file.

After changing either value, rebuild and reflash for it to take effect, and
check `server/captures/` to see the actual result.

## 7. A few other things worth knowing

- **No speaker audio yet** — this bench-test flow deliberately prints the
  answer as text instead of playing it aloud. The speaker/amp still has an
  unresolved static/faint-audio issue; `beeptest` (see step 3) is there to
  help isolate that separately if you come back to it.
- **Touch sensitivity not yet fully calibrated** — `pins.h`'s
  `TOUCH_THRESHOLD` is still a placeholder value, not a number taken from a
  real `selftest` run on your actual coin/wiring. If the coin ever stops
  triggering reliably or fires on its own, re-run `selftest`, note the
  reported touch reading, and update `TOUCH_THRESHOLD` in `pins.h` to match.
- **Camera orientation** — if the photo in `server/captures/` looks flipped
  or mirrored, `CAMERA_VFLIP` and `CAMERA_HMIRROR` in `pins.h` control this.
  Only one of the two should usually be set to `1` for a true mirror-image
  fix (both set to `1` together instead rotates the image 180°).
- **Photo blur** — this camera has a fixed-focus lens; it needs the subject
  roughly 15–30cm away to focus properly, and it has no image stabilisation,
  so keep the board steady for a moment when you trigger it.
- **Answer accuracy and speed** — the vision model in use
  (`VISION_MODEL` in `server/.env`, defaulting to a free-tier OpenRouter
  model) is the main factor in both how accurate answers are and how long
  they take to come back. A wrong answer is often the photo being blurry or
  the free model, not a bug in the code.
- **Full troubleshooting reference** — `docs/BENCH_TEST_PIPELINE.md` has a
  more detailed list of problems hit and fixes that worked, if something
  here doesn't cover what you're seeing.
