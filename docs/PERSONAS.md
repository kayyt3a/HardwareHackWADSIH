# Vocalens — the two people we built this for

Two personas, one device, two configurations (`profile_type` in
`server/profile_store.py`). Same hardware, same firmware, same pipeline —
what changes is what the device remembers and how it uses it.

**Margaret is a synthetic persona**, built from the challenge brief's own
descriptions and published research (Vision Australia, APH ConnectCenter,
National Eye Health Survey). **Ethan is a real teammate** — see the framing
note in his section, which matters.

We did not interview or test on anyone with disability — the brief is
explicit about consent and about using synthetic data, and we used
ourselves as test users as it suggests. Say this plainly if asked: it's a
limitation, not something to hide, and "we'd validate with real users next"
is the honest next step.

A note on language, straight from the brief: *"Describe what the device does
and who it is for; avoid framing people as problems to be managed."* Both
briefs below are written as people with lives, not as lists of deficits.
Keep that framing in the pitch.

---

## Margaret, 78 — the demo persona

**`profile_type = "dosage"`**

### Who she is

Margaret has lived in the same Bayswater house for thirty-one years. She
still drives to the shops in daylight, does the crossword with a lit
magnifier, and hosts her book club on the first Tuesday of the month. She
was a primary school teacher for twenty-six years and is not remotely
intimidated by technology — she just can't read it any more.

She has age-related macular degeneration, diagnosed six years ago. Central
vision is largely gone; her peripheral vision still works, which means she
navigates her own home confidently and can spot someone waving from across
a room, but she cannot read anything she looks directly at.

She manages nine medications daily.

### Her actual Tuesday

7:15am. Morning tablets. She keeps them in a specific order on the
windowsill — an order she built herself and rechecks by position, not by
reading. Two of the bottles are the same size and shape. She has a rubber
band round one of them.

**That rubber band is the thing to say out loud in the pitch.** The baseline
we're replacing isn't "nothing." It's a system she invented herself,
maintains herself, and which fails silently the moment someone tidies the
windowsill or the pharmacy changes a bottle.

11am. Her daughter drops off shopping. Margaret can't check the use-by
dates, so she either asks — which she hates doing, and does less often than
she should — or she doesn't check.

4pm. A new prescription arrives. The dispensing label is 8-point type.

### What she needs from a device

Not a reading machine. She needs *one specific fact, right now*: which
bottle is this, what's the date, is this the shampoo or the conditioner.
She needs it without asking another person, because the asking is the part
that costs her something.

### Why the dosage profile matters for her

Her profile holds her age, weight, and — the demo-relevant part — her
allergies. When she points at a box, Vocalens reads it *and* flags that it
contains something she's listed. It does **not** tell her whether to take
it. That distinction is the whole design:

> "It surfaces what's printed on the box. It never gives her a verdict.
> Margaret decides, or her pharmacist does — this device is not in that
> loop, and we built it deliberately so it can't be."

### Her question for us

*"What happens when it gets it wrong?"* — She's not asking rhetorically.
She can't check its answer. This is why the confidence gate exists, and why
the deliberate-failure beat is in the demo.

---

## Ethan — the second configuration

**`profile_type = "reminders"`**

### An honest framing note — read this before you write the slide

Ethan is a real person on your team, not an invention. That's a strength:
the brief explicitly says *"use synthetic data and your own team as test
users,"* and "he's worn it for three weeks" is worth more than any
invented backstory.

**But do not attribute low vision to him as if it were fact.** Naming a
real teammate on stage and giving him a condition he doesn't have is the
kind of thing that, once a judge realises it, costs you credibility on
everything else you said. The fix is simple and makes the pitch *better*:

> "Ethan's on our team — computer science, commutes in from [suburb], lives
> on his phone. He doesn't have low vision. But when we asked what a
> *younger* user would need from this, he's who we designed around, and
> he's the one who's actually been wearing it."

Real person, real daily routine, hypothetical clearly labelled. That's both
honest and more concrete than a fabricated character.

### Who he is

A computer science student in Perth. Commutes by train. Works with a laptop
all day, phone constantly in hand, entirely comfortable with technology —
he'd be the first person to tell you a device is pointless if his phone
already does it.

**Ethan is the harder pitch, and that's exactly why he's useful.** He is not
someone for whom "assistive technology" is a novelty. If a younger,
tech-fluent user wouldn't choose this over the phone already in their
pocket, the device has no younger market — and the brief specifically asks
you to name your answer to that.

If Ethan were losing central vision — the same thing happening to Margaret,
fifty years earlier — nothing about his day would slow down to accommodate
it. That's the design problem.

### His actual Thursday

8:10am. On the train, standing, one hand on the rail, coffee in the other.
A poster for something on at the Cultural Centre. He'd have to put the
coffee down, get his phone out, unlock it, open an app, and aim — by which
point his stop is coming up. He doesn't bother. **This is the moment the
device wins:** hands full, standing, moving, and he just taps his temple.

12:30pm. A friend mentions drinks Friday at a place he doesn't know. He'd
normally type it into his phone. With Vocalens he says *"remember this"*
and keeps eating.

6pm. Walking to the station: *"what do I have coming up."* It reads back
what he saved. Nothing was typed. Nothing synced from anyone's calendar. It
only knows what he told it.

### Why the reminders profile matters for him

He's not managing a health condition — he's managing a life. So his profile
holds **nothing medical at all**, and this is a real engineering decision,
not a marketing line:

> `dosage_context_summary()` returns `None` unless the profile is in dosage
> mode. In Ethan's configuration, health facts aren't filtered out
> downstream — they're never assembled in the first place. There is no
> health data in his device to leak, because the code path that would build
> it never runs.

### His question for us

*"Why would I use this instead of my phone?"* — Answer it directly, don't
dodge: hands-free, no unlock, no app, and it's the same device that already
does his reading, so it isn't one more thing to carry or one more app to
remember.

---

## How to use these in the pitch

**Lead with Margaret.** She's the demo persona, she's the brief's central
cohort ("older Western Australians"), and the dosage read is the more
striking live demo.

**Bring in Ethan on one slide, late** — probably alongside "what's next" or
the two-modes explanation. His job is to show the device isn't a
single-purpose gadget for one narrow group, and to prove you've tested the
"why not a phone" objection against your *most* skeptical possible user
rather than your most sympathetic one.

**Have Ethan say his own line, if he's presenting.** "I've worn this for
three weeks" lands very differently coming from the person who wore it.

**Do not demo both live.** One configuration, set up properly, demoed
cleanly. Ethan's mode is explained, not performed — it doubles your setup
and doubles what can break in a three-minute slot.

### Lines worth having ready

- *"The baseline isn't nothing. It's a rubber band round a pill bottle."*
- *"It surfaces what's printed. It never gives a verdict."*
- *"In Ethan's configuration there's no health data to leak, because the
  code that would assemble it never runs."*
- *"Margaret can't check its answer. That's why it has to be able to say it
  doesn't know."*
