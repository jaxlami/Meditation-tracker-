# Roadmap

Everything planned for the Meditation app, one list. Status: **v2** (in this release), **On hold**, **Later**.

---

## In v2

### Journal — v2
The History tab is now **Journal**: free journal entries and meditation sessions in one timeline.
- **+** menu: *Journal entry* or *Meditation session*.
- An entry: mood first (same picker as sessions), then free writing, then topic **tags** (several per entry).
- **Smart tags**, on-device: matches your existing tags and common topics (romance, gym, childhood, work…),
  related words via Apple's NaturalLanguage, and Apple Intelligence where available. Suggestions appear as you write;
  a new entry saved without tags gets the top suggestions automatically.
- Filter chips with counts (all · entries · sessions · each #tag), month groups, search across text and tags.

### Daily reflection — v2
After each session, the log form asks a short affirmation-style question that changes every day
(e.g. *"What quality do you want to carry into today?"*). It sits directly below Notes.
- Same question all day, a new one tomorrow (picked from a hand-written list in `Helpers/ReflectionPrompts.swift`).
- "Different question" button if today's doesn't land.
- Today's question is shown on the Today screen before you sit (as an intention); once answered, your answer shows there instead.
- Answers appear on the Calendar day view and in History, are searchable, and are included in the CSV export.

### Warm, editorial redesign — v2
Paper and ink palette with a single sage accent and clay for warmth, serif display type (New York),
hairline cards, no emoji (mood is shown with a drawn glyph), calmer copy.

---

## On hold

### Do Not Disturb / Focus mode
Goal: no notifications or distractions while meditating, switchable from Settings.

**Constraint:** iOS does not let third-party apps turn on Do Not Disturb or a Focus directly. Options considered:

| Option | How it works | Trade-offs |
|---|---|---|
| **A. Guided Focus + in-app quiet mode** *(recommended)* | A Settings toggle plus a one-time guide: iOS Settings → Focus → (e.g. "Meditation") → Add Schedule → **App** → Meditation. iOS then turns the Focus on whenever the app is open. The app itself also goes quiet during a session. | Native and reliable, no app switching. Focus stays on while the app is open, not only during a session. One-time setup by the user. |
| **B. Shortcuts-triggered Focus** | The app runs a user-installed Shortcut (via `shortcuts://x-callback-url/run-shortcut?name=…`) to turn Focus on at session start and off at the end. | Precise on/off. Briefly jumps to the Shortcuts app each time; more setup. |
| **C. In-app quiet mode only** | Suppress the app's own reminders during a session, no haptics, hide the status bar, strip extra UI from the timer. | Simple. Doesn't stop other apps' notifications. |

"In-app quiet mode" (part of A and C) would include: holding back the daily reminder while a session runs,
no haptics, a chrome-free timer and an optional dimmed screen.

---

## Later

- **Apple Health**: write mindful minutes (needs the HealthKit capability, which requires a paid developer account).
- **iCloud sync** between devices.
- **Home Screen / Lock Screen widget** showing your streak and today's question.
- **Interval bells** during long sessions.
- **Reflection extras**: browse past questions and answers, favorite prompts, write your own prompts.
- **Journal-only export** (reflections as a plain text / Markdown file).
- **Custom app icon** to match the new design.
- **Paper grain texture** on backgrounds. Removed during v2 after the app showed a blank screen in testing; it later turned out the simulator can simply be slow on first launch, so the grain may not have been the cause. Worth retrying with a pre-rendered asset.
- **Journal follow-ups**: show journal entries on Calendar days, export the journal (text/Markdown), rename and merge tags, mood trends per tag in Stats.
