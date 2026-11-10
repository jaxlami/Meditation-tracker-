# Meditation Tracker (iOS)

A simple, native iPhone app (SwiftUI + SwiftData) for tracking your meditation practice.
Everything is stored on your phone, and nothing is uploaded anywhere.

## Features

- **Meditation timer** with presets (5–60 min) or a custom length, plus a breathing-guide animation,
  pause/resume and finish early. It plays a chime when it ends, and a notification fires if the phone is locked.
  The screen stays awake while it runs.
- **Log sessions**, either from the timer automatically or manually for past sits:
  - **When:** date and start time
  - **How long:** duration
  - **Where:** type a place, tap *Use Current Location*, or pick from places you've used before
  - Technique (mindfulness, breathing, body scan, loving-kindness…)
  - Mood before and after (optional)
  - Notes
- **Calendar**: a month view where days you meditated are highlighted (solid when you hit your daily goal).
  Tap a day to see or edit its sessions or add one. Swipe to change months.
- **Streaks**: current and longest streak in days.
- **Stats**: total time, session count, average length, favorite time of day, a 7- and 30-day chart against
  your goal, a technique breakdown, top places and average mood change.
- **History**: every session grouped by month, searchable. Swipe to delete, tap to edit.
- **Settings**: daily goal, default timer length, chime on/off, a daily reminder notification,
  **CSV export** (to Files, Numbers or Excel) and delete all data.

## Running it on your iPhone

You need a Mac with **Xcode 16 or newer** (free from the Mac App Store). The iPhone needs **iOS 17+**.

1. Open `MeditationTracker.xcodeproj` in Xcode.
2. Click the **MeditationTracker** project in the sidebar → **Signing & Capabilities** tab.
   - Under *Team*, choose your Apple ID. Click *Add Account…* if needed; a free Apple ID works.
   - If Xcode says the bundle identifier is taken, change `com.yourname.MeditationTracker` to something unique,
     e.g. `com.<yourname>.MeditationTracker`.
3. Plug in your iPhone (or pick it over Wi-Fi) and select it as the run destination at the top of Xcode.
4. Press **▶ Run**.
5. The first time, on the iPhone go to **Settings → General → VPN & Device Management**, trust your developer
   certificate, and turn on **Developer Mode** if iOS asks (Settings → Privacy & Security).

> With a free Apple ID, apps you install yourself expire after 7 days. Just hit Run again in Xcode;
> your data is kept. A paid Apple Developer account ($99/yr) lifts that limit and lets you use TestFlight.

You can also try it without a phone by choosing an iPhone **Simulator** as the run destination.

## Project layout

```
MeditationTracker/
  MeditationTrackerApp.swift      App entry, sets up SwiftData storage
  Models/MeditationSession.swift  The saved session + technique and mood types
  Views/                          Today, Timer, Log/Edit, Calendar, History, Stats, Settings
  Helpers/                        Streak math, notifications, location lookup, CSV export
  Assets.xcassets                 App icon and accent color
```

## Ideas for later

- Sync **mindful minutes to Apple Health** (needs the HealthKit capability, which requires a paid developer account)
- iCloud sync between devices
- Home Screen widget showing your streak
- Interval bells during long sessions
