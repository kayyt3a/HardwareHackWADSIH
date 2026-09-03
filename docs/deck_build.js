const pptxgen = require("pptxgenjs");

const NAVY = "0B4F6C";
const DEEP = "072F42";
const TEAL = "137A7F";
const AMBER = "F2A65A";
const CREAM = "FDF6EC";
const LIGHT = "F4F8F9";
const GREY = "5A6B78";
const WHITE = "FFFFFF";

const HEAD = "Cambria";
const BODY = "Calibri";

const p = new pptxgen();
p.layout = "LAYOUT_WIDE";           // 13.3 x 7.5
p.author = "Team FourSight";
p.title = "VocaLens";

const W = 13.3, H = 7.5, M = 0.7;

// amber numbered disc — the repeated motif across the deck
function disc(s, x, y, label, d = 0.5) {
  s.addShape(p.ShapeType.ellipse, {
    x, y, w: d, h: d, fill: { color: AMBER },
  });
  s.addText(label, {
    x, y, w: d, h: d, isTextBox: true, margin: 0,
    align: "center", valign: "middle",
    fontFace: HEAD, fontSize: 15, bold: true, color: NAVY,
  });
}

function card(s, x, y, w, h, fill) {
  s.addShape(p.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.08,
    fill: { color: fill || LIGHT },
    shadow: { type: "outer", color: "9BB0BC", blur: 10, offset: 2, angle: 90, opacity: 0.25 },
  });
}

/* ============================ 1 — TITLE ============================ */
let s = p.addSlide();
s.background = { color: DEEP };

s.addText("VocaLens", {
  x: M, y: 2.2, w: 9, h: 1.5, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 80, bold: true, color: WHITE, charSpacing: -1,
});
s.addText("Glasses that read the world aloud.", {
  x: M, y: 3.7, w: 10, h: 0.7, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 26, color: AMBER,
});
s.addText("Team FourSight   ·   Hardware Hack 2026   ·   Challenge 1C — Eyes for Labels", {
  x: M, y: 6.3, w: 11.5, h: 0.4, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 14, color: "8FB0BF",
});
s.addNotes("Open by naming her, not the technology. 'This is Margaret.' Then the rubber band line on the next slide.");

/* ============================ 2 — MARGARET ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("This is Margaret.", {
  x: M, y: 0.75, w: 7, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: NAVY,
});
s.addText("78 years old.  Macular degeneration.  Nine medications a day.", {
  x: M, y: 1.6, w: 7, h: 0.5, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 17, color: GREY,
});

s.addText(
  "She keeps her tablets in an order she invented, on the windowsill, and rechecks them by position — not by reading.\n\nTwo of the bottles are the same size and shape.\nSo she has a rubber band round one of them.",
  { x: M, y: 2.45, w: 6.4, h: 2.2, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 16, color: "2C3E4C", lineSpacing: 24 });

card(s, M, 4.95, 6.4, 1.5, CREAM);
s.addText("“The baseline isn’t nothing.\nIt’s a rubber band round a pill bottle.”", {
  x: M + 0.35, y: 5.1, w: 5.7, h: 1.2, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 18, italic: true, bold: true, color: NAVY, lineSpacing: 26,
});

// right: stat stack
card(s, 7.6, 0.75, 5.0, 5.7, LIGHT);

s.addText("60%", {
  x: 7.95, y: 1.05, w: 4.3, h: 1.05, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 66, bold: true, color: TEAL,
});
s.addText("of people with vision loss struggle to locate or identify their own medication",
  { x: 7.95, y: 2.1, w: 4.3, h: 0.9, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 14, color: "2C3E4C", lineSpacing: 19 });

s.addText("64%", {
  x: 7.95, y: 3.25, w: 2.0, h: 0.75, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 42, bold: true, color: NAVY,
});
s.addText("report missing doses", {
  x: 7.95, y: 4.0, w: 2.0, h: 0.6, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 12, color: GREY, lineSpacing: 16,
});
s.addText("33%", {
  x: 10.2, y: 3.25, w: 2.1, h: 0.75, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 42, bold: true, color: NAVY,
});
s.addText("report inaccurate dosing or spilling", {
  x: 10.2, y: 4.0, w: 2.1, h: 0.6, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 12, color: GREY, lineSpacing: 16,
});

s.addText("Her question for us:  “What happens when it gets it wrong?”", {
  x: 7.95, y: 5.05, w: 4.3, h: 0.7, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 14, bold: true, italic: true, color: TEAL, lineSpacing: 19,
});
s.addText("Source: APH ConnectCenter — medication management for blind & low vision", {
  x: 7.95, y: 5.95, w: 4.3, h: 0.35, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 9, color: "8A9AA5",
});
s.addNotes("The rubber band is the line to land. It is a system she invented and maintains, and it fails silently the moment someone tidies the windowsill. Her question is why we built a confidence gate and why beat 3 of the demo exists.");

/* ============================ 3 — PREVALENCE ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("She is not alone", {
  x: M, y: 0.7, w: 8, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: NAVY,
});
s.addText("Glasses and surgery cannot fully correct many of these conditions.\nThis is not a shrinking problem.", {
  x: M, y: 1.55, w: 8.5, h: 0.8, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 17, color: GREY, lineSpacing: 23,
});

const stats = [
  ["400,000", "Cataracts"],
  ["400,000", "Diabetic retinopathy"],
  ["200,000", "Macular degeneration"],
  ["160,000", "Glaucoma"],
];
stats.forEach(([n, label], i) => {
  const x = M + i * 3.05;
  card(s, x, 2.75, 2.75, 1.95, LIGHT);
  s.addText(n, {
    x: x + 0.22, y: 2.95, w: 2.3, h: 0.75, isTextBox: true, margin: 0,
    fontFace: HEAD, fontSize: 34, bold: true, color: TEAL,
  });
  s.addText(label, {
    x: x + 0.22, y: 3.72, w: 2.3, h: 0.8, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 14, color: "2C3E4C", lineSpacing: 18,
  });
});

s.addText("in Australia", {
  x: M, y: 4.8, w: 4, h: 0.4, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 13, italic: true, color: GREY,
});

card(s, M, 5.4, 11.9, 1.15, CREAM);
s.addText([
  { text: "Sixteen of the thirty people in this room are wearing glasses. ", options: { bold: true } },
  { text: "That is not our statistic — it is our mounting bracket. VocaLens clips onto what you already own.", options: {} },
], {
  x: M + 0.35, y: 5.62, w: 11.2, h: 0.75, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 16, color: NAVY, lineSpacing: 22,
});

s.addText("Source: AIHW eye health report", {
  x: 9.4, y: 4.8, w: 3.2, h: 0.35, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 9, color: "8A9AA5", align: "right",
});
s.addNotes("Count the glasses in the room before you present and update the number. Do NOT say 'half of you could end up like Margaret' — glasses mean your vision IS correctable, which contradicts this slide. The honest version is the one on the slide: they already accepted a device on their face, and it is the platform we clip onto.");

/* ============================ 4 — THE PRODUCT ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("VocaLens", {
  x: M, y: 0.7, w: 7, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: NAVY,
});
s.addText("A lightweight add-on to glasses you already own.", {
  x: M, y: 1.55, w: 6.6, h: 0.5, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 17, color: GREY,
});

const feats = [
  ["1", "Reads text aloud", "Point your face at a label and ask. The answer comes back as speech."],
  ["2", "Scans barcodes", "Recognised products answer instantly, with no model call at all."],
  ["3", "One button", "No app, no unlock, no aiming a screen you cannot see."],
  ["4", "Comfortable and resilient", "Two thin pods that clip on and off. Nothing glued to the frame."],
];
feats.forEach(([n, title, desc], i) => {
  const y = 2.35 + i * 1.12;
  disc(s, M, y, n, 0.46);
  s.addText(title, {
    x: M + 0.68, y: y - 0.04, w: 5.6, h: 0.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 17, bold: true, color: NAVY,
  });
  s.addText(desc, {
    x: M + 0.68, y: y + 0.34, w: 5.6, h: 0.6, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 13, color: GREY, lineSpacing: 17,
  });
});

card(s, 7.6, 0.7, 5.0, 6.05, LIGHT);
s.addText("PRODUCT PHOTO", {
  x: 7.9, y: 3.2, w: 4.4, h: 0.5, isTextBox: true, margin: 0,
  align: "center", fontFace: BODY, fontSize: 15, bold: true, color: "9BB0BC",
});
s.addText("Replace with the pods clipped onto real glasses, worn.", {
  x: 7.9, y: 3.75, w: 4.4, h: 0.6, isTextBox: true, margin: 0,
  align: "center", fontFace: BODY, fontSize: 12, italic: true, color: "9BB0BC", lineSpacing: 16,
});
s.addNotes("PLACEHOLDER — swap in the photo of the assembled device on a face before demo day. A worn shot beats a bench shot.");

/* ============================ 5 — META REBUTTAL ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("“Isn’t this just a cheap Meta glasses knockoff?”", {
  x: M, y: 0.7, w: 11.9, h: 0.9, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 38, bold: true, color: NAVY,
});

card(s, M, 1.95, 5.75, 4.5, LIGHT);
s.addText("$800–900", {
  x: M + 0.4, y: 2.2, w: 5.0, h: 0.85, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: "9BB0BC",
});
s.addText("Meta glasses", {
  x: M + 0.4, y: 3.05, w: 5.0, h: 0.4, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 18, bold: true, color: GREY,
});
s.addText("A phone strapped to your face. Notifications, social media, a dozen features an elderly or low-vision user will never touch — and may never even discover.",
  { x: M + 0.4, y: 3.6, w: 5.0, h: 2.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 14, color: GREY, lineSpacing: 20 });

card(s, 6.85, 1.95, 5.75, 4.5, CREAM);
s.addText("under $100", {
  x: 7.25, y: 2.2, w: 5.0, h: 0.85, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: TEAL,
});
s.addText("VocaLens", {
  x: 7.25, y: 3.05, w: 5.0, h: 0.4, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 18, bold: true, color: NAVY,
});
s.addText([
  { text: "One job, done reliably.", options: { bold: true, breakLine: true } },
  { text: "Every feature gets used — we included only what earns its place.", options: { breakLine: true } },
  { text: "Head-aim replaces screen-aim: no aiming a screen you can’t see.", options: { breakLine: true } },
  { text: "Clips onto the glasses already on your face.", options: {} },
], { x: 7.25, y: 3.6, w: 5.0, h: 2.4, isTextBox: true, margin: 0,
     fontFace: BODY, fontSize: 14, color: "2C3E4C", lineSpacing: 21, paraSpaceAfter: 6 });

s.addText("Bone-conduction audio keeps answers private to the wearer — that is the production design. This prototype uses a small speaker, built entirely from the kit we were given.",
  { x: M, y: 6.6, w: 11.9, h: 0.55, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 12.5, italic: true, color: GREY, lineSpacing: 17 });
s.addNotes("Say the speaker swap out loud before a judge spots it. Framing it as a deliberate zero-purchase constraint reads as discipline, not compromise.");

/* ============================ 6 — LIVE DEMO ============================ */
s = p.addSlide();
s.background = { color: DEEP };

s.addText("LIVE DEMO", {
  x: M, y: 0.85, w: 8, h: 1.0, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 58, bold: true, color: WHITE, charSpacing: 1,
});

const beats = [
  ["1", "A barcode read", "Instant. Zero model calls."],
  ["2", "An open question", "“What does this say?”"],
  ["3", "A deliberate failure", "It says “I can’t see that clearly” instead of guessing."],
];
beats.forEach(([n, title, desc], i) => {
  const y = 2.4 + i * 1.35;
  disc(s, M, y, n, 0.62);
  s.addText(title, {
    x: M + 0.95, y: y - 0.06, w: 6.5, h: 0.5, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 24, bold: true, color: WHITE,
  });
  s.addText(desc, {
    x: M + 0.95, y: y + 0.44, w: 8.5, h: 0.45, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 15, color: "9FC2D2",
  });
});

card(s, 8.6, 2.35, 4.0, 3.75, "0E3D52");
s.addText("The third one matters most.", {
  x: 8.9, y: 2.65, w: 3.4, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 20, bold: true, italic: true, color: AMBER, lineSpacing: 26,
});
s.addText("Margaret cannot check the answer herself. A device that admits uncertainty is worth more to her than one that is usually right.",
  { x: 8.9, y: 3.6, w: 3.4, h: 2.2, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 14, color: "CFE3EC", lineSpacing: 20 });
s.addNotes("Rehearse beat 3 — do not hope it happens. Have a deliberately bad image ready: too close, too dark, or badly angled.");

/* ============================ 7 — HOW IT WORKS ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("How it works", {
  x: M, y: 0.7, w: 8, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: NAVY,
});

const flow = [
  ["Glasses", "Camera and mic capture on trigger — never continuously."],
  ["Server", "One round trip over the local network. Nothing leaves the room."],
  ["Fast path", "Barcode decode first: free, instant, no model call."],
  ["Speak", "The model runs only when needed, then text-to-speech."],
];
flow.forEach(([title, desc], i) => {
  const x = M + i * 3.05;
  card(s, x, 2.0, 2.75, 2.5, LIGHT);
  disc(s, x + 0.25, 2.25, String(i + 1), 0.46);
  s.addText(title, {
    x: x + 0.25, y: 2.85, w: 2.3, h: 0.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 18, bold: true, color: NAVY,
  });
  s.addText(desc, {
    x: x + 0.25, y: 3.3, w: 2.3, h: 1.1, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 12.5, color: GREY, lineSpacing: 17,
  });
  if (i < 3) {
    s.addText("→", {
      x: x + 2.78, y: 3.0, w: 0.28, h: 0.4, isTextBox: true, margin: 0,
      align: "center", fontFace: BODY, fontSize: 20, bold: true, color: AMBER,
    });
  }
});

card(s, M, 4.95, 11.9, 1.65, CREAM);
s.addText("AI earns its place", {
  x: M + 0.4, y: 5.15, w: 4.0, h: 0.45, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 20, bold: true, color: NAVY,
});
s.addText("A recognised barcode answers with zero model calls. The vision model runs only for the genuinely open-ended questions — a label, a colour, a comparison — that actually need it.",
  { x: M + 0.4, y: 5.62, w: 11.1, h: 0.8, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 14, color: "2C3E4C", lineSpacing: 19 });
s.addNotes("Worth saying explicitly in a room where most projects call a model for everything. This is a design argument, not a cost saving.");

/* ============================ 8 — DIGNITY ============================ */
s = p.addSlide();
s.background = { color: WHITE };

s.addText("Designed with dignity", {
  x: M, y: 0.65, w: 8, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 44, bold: true, color: NAVY,
});

const dig = [
  ["Who’s in control", "Only the wearer hears the answer. No escalation, no third party notified, ever."],
  ["Collects only what’s needed", "Capture happens on trigger. No continuous recording, nothing stored beyond one request."],
  ["Looks ordinary", "Reads as glasses, not medical equipment, at a friend’s kitchen bench."],
  ["Not a medical device", "Surfaces printed facts. Never a safety verdict, never a recommendation."],
];
dig.forEach(([title, desc], i) => {
  const x = M + (i % 2) * 4.35;
  const y = 1.7 + Math.floor(i / 2) * 1.95;
  card(s, x, y, 4.05, 1.7, LIGHT);
  s.addText(title, {
    x: x + 0.3, y: y + 0.2, w: 3.5, h: 0.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 16, bold: true, color: TEAL,
  });
  s.addText(desc, {
    x: x + 0.3, y: y + 0.65, w: 3.5, h: 0.9, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 12.5, color: "2C3E4C", lineSpacing: 17,
  });
});

card(s, 9.4, 1.7, 3.2, 3.9, CREAM);
s.addText("under", {
  x: 9.65, y: 2.05, w: 2.7, h: 0.35, isTextBox: true, margin: 0,
  align: "center", fontFace: BODY, fontSize: 14, color: GREY,
});
s.addText("$100", {
  x: 9.65, y: 2.35, w: 2.7, h: 1.0, isTextBox: true, margin: 0,
  align: "center", fontFace: HEAD, fontSize: 54, bold: true, color: NAVY,
});
s.addText("per unit in parts", {
  x: 9.65, y: 3.35, w: 2.7, h: 0.35, isTextBox: true, margin: 0,
  align: "center", fontFace: BODY, fontSize: 13, bold: true, color: GREY,
});
s.addText("XIAO ESP32S3 Sense · camera · amplifier and speaker · trigger · battery · two printed pods that clip to glasses the wearer already owns",
  { x: 9.65, y: 3.85, w: 2.7, h: 1.5, isTextBox: true, margin: 0,
    align: "center", fontFace: BODY, fontSize: 11, color: GREY, lineSpacing: 15 });

s.addText("Built entirely from the kit every team was given. No external purchases, so nothing here depended on a delivery arriving.",
  { x: M, y: 5.85, w: 11.9, h: 0.55, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 13, italic: true, color: GREY, lineSpacing: 18 });
s.addNotes("Cost list now matches what was actually built — speaker rather than bone-conduction transducer, clip-on pods rather than a printed frame. Slide 5 already concedes the speaker, so these no longer contradict.");

/* ============================ 9 — SCOPE + CLOSE ============================ */
s = p.addSlide();
s.background = { color: DEEP };

s.addText("What we deliberately didn’t build", {
  x: M, y: 0.8, w: 9, h: 0.8, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 40, bold: true, color: WHITE,
});
s.addText("Scope we chose, not scope we missed.", {
  x: M, y: 1.65, w: 8, h: 0.45, isTextBox: true, margin: 0,
  fontFace: BODY, fontSize: 17, color: AMBER,
});

const nots = [
  ["Carer notifications or location tracking", "The wearer is the only person in the loop. That is the point, not an omission."],
  ["A synced calendar", "Reminders are built by the wearer, on purpose. Nothing arrives from anyone else."],
  ["Multi-language support", "Next on the list — and the clearest next step we would take."],
];
nots.forEach(([title, desc], i) => {
  const y = 2.5 + i * 1.15;
  s.addText("—", {
    x: M, y: y, w: 0.4, h: 0.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 20, bold: true, color: AMBER,
  });
  s.addText(title, {
    x: M + 0.5, y: y - 0.02, w: 7.5, h: 0.4, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 18, bold: true, color: WHITE,
  });
  s.addText(desc, {
    x: M + 0.5, y: y + 0.38, w: 7.5, h: 0.5, isTextBox: true, margin: 0,
    fontFace: BODY, fontSize: 13, color: "9FC2D2", lineSpacing: 18,
  });
});

card(s, 8.9, 2.5, 3.7, 2.7, "0E3D52");
s.addText("It surfaces what is printed.\nIt never gives a verdict.", {
  x: 9.2, y: 3.05, w: 3.1, h: 1.6, isTextBox: true, margin: 0,
  align: "center", fontFace: HEAD, fontSize: 20, bold: true, italic: true,
  color: AMBER, lineSpacing: 28,
});

s.addText("VocaLens", {
  x: M, y: 6.05, w: 5, h: 0.6, isTextBox: true, margin: 0,
  fontFace: HEAD, fontSize: 30, bold: true, color: WHITE,
});
s.addText("Team FourSight — thank you", {
  x: 7.6, y: 6.2, w: 5.0, h: 0.45, isTextBox: true, margin: 0,
  align: "right", fontFace: BODY, fontSize: 16, color: "8FB0BF",
});
s.addNotes("Close on the verdict line. It answers the dignity question and the medical-device question at the same time.");

p.writeFile({ fileName: "VocaLens_Pitch_Deck.pptx" }).then(() => console.log("written"));
