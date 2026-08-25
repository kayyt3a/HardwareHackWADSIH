# Judging criteria checklist (from the challenge brief)

Fill this in as the build progresses — it's what you'll actually say on demo night.

- **Persona**: Margaret, 78, macular degeneration. Describe her actual day —
  what specific labels trip her up (medication vs. supplement bottles that
  look identical, use-by dates, shampoo vs conditioner).
- **Who is in control?**: Device only speaks when the button is pressed. No
  autonomous escalation, no third party notified, ever — this device has no
  concept of a carer.
- **What does it look like on a kitchen bench?**: Design goal — should not
  look medical. TODO: 3D-print an enclosure that reads as a torch/pointer, not
  a diagnostic tool.
- **What does it do when it's wrong?**: Server returns `needs_reposition` and
  a confidence score; below threshold, device says "I'm not sure, try moving
  closer" instead of guessing. Never state a low-confidence read as fact.
- **Does it collect more than it needs?**: Camera captures a single frame only
  on explicit button press. No video, no continuous recording, no storage.
  State this plainly in the pitch.
- **Could the person set it up themselves?**: TODO — decide WiFi provisioning
  approach (e.g. BLE provisioning or a captive portal) so setup doesn't
  permanently require a technical third party.
- **What does it cost?**: TODO — itemise: XIAO ESP32S3 Sense (~$20-25 USD),
  ToF/ultrasonic sensor, vibration motor, MAX98357A amp + speaker, battery,
  3D-printed enclosure. Target a bill of materials under $40-50.
- **What's next / what did you deliberately not build?**: e.g. deliberately
  not building carer notifications, not building multi-language support yet,
  not attempting continuous/wearable mode.
