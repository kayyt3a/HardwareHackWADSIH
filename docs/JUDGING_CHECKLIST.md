# Judging criteria checklist (from the challenge brief)

Fill this in as the build progresses — it's what you'll actually say on demo night.

- **Persona**: Margaret, 78, macular degeneration. Describe her actual day —
  what specific labels trip her up (medication vs. supplement bottles that
  look identical, use-by dates, shampoo vs conditioner) — and why a worn
  device beats a handheld one for her specifically (loses/forgets handheld
  items; glasses are already a habit she has if she's low-vision).
- **Who is in control?**: Device only answers when triggered (wake word or
  temple touch) and only to the wearer, through a bone-conduction transducer
  rather than a speaker — no one else in the room hears the answer. No
  autonomous escalation, no third party notified, ever — this device has no
  concept of a carer.
- **What does it look like sitting on a kitchen bench / worn at a friend's
  visit?**: Design goal — should read as ordinary glasses, not medical
  equipment. TODO: 3D-print a frame/temple housing that keeps the camera and
  electronics as unobtrusive as possible.
- **What does it do when it's wrong?**: Server returns `needs_reposition` and
  a confidence score; below threshold, device says it can't see clearly and
  asks the wearer to move or turn their head, instead of guessing. Never
  state a low-confidence read as fact.
- **Does it collect more than it needs?**: Camera and mic only capture on an
  explicit trigger (wake word match or touch pad). No continuous recording,
  no storage beyond a single request. This needs to be stated very plainly
  in the pitch — a face-worn always-available camera reads as more
  surveillance-adjacent than a handheld one to an onlooker, so the "off by
  default" claim has to be visibly true, not just asserted (consider a
  capture-indicator LED as a trust signal).
- **Could the person set it up themselves?**: TODO — decide WiFi provisioning
  approach (e.g. BLE provisioning or a captive portal) so setup doesn't
  permanently require a technical third party.
- **What does it cost?**: TODO — itemise: XIAO ESP32S3 Sense (~$20-25 USD),
  bone-conduction transducer + small amp, touch pad, battery, frame/enclosure
  fabrication. Target a bill of materials under $40-50. Wake-word hardware
  itself is free (on-device, no extra chip) but factor in dev time.
- **What's next / what did you deliberately not build?**: e.g. deliberately
  not building carer notifications or location tracking, not building
  multi-language support yet, deliberately shipped with a manual touch-pad
  trigger as backup while the custom wake word was still in training.
