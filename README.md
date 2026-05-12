# Teamodoro — Apple Ecosystem

> Synchronized Pomodoro productivity for iOS & macOS. Every team member on the exact same second.

---

## What is Teamodoro?

<cite index="1-2,1-3,1-4">Teamodoro is a synchronized Pomodoro productivity suite built natively for the Apple ecosystem, providing a seamless experience across iPhones and Macs. The core value is **"Team Focus"** — every team member is on the exact same second of the work/break cycle.</cite>

---

## How Sync Works

<cite index="1-6,1-7">Synchronization is achieved through a deterministic algorithm based on the Unix Epoch. The app does not "listen" for a server tick — it calculates its state independently using the system clock.</cite>

```swift
let cycleDuration: TimeInterval = 7800 // 130 minutes in seconds
let currentTime = Date().timeIntervalSince1970
let roomOffset = SharedStorage.getOffset() // Provided once on join

let elapsed = (currentTime - roomOffset)
let positionInCycle = elapsed.truncatingRemainder(dividingBy: cycleDuration)
```

---

## Platform Features

### macOS

- <cite index="1-9">**Menu Bar (StatusBar):** A persistent icon showing a miniature countdown and color state (Red/Green).</cite>
- <cite index="1-10">**Global Hotkeys:** `Cmd+Shift+P` to toggle the UI or join/leave rooms.</cite>
- <cite index="1-12">**Focus Filter:** Integration with macOS Focus Modes to silence notifications during "Work" blocks.</cite>

### iOS

- <cite index="1-13">**Live Activities:** Real-time countdown on the Lock Screen and Dynamic Island.</cite>
- <cite index="1-14">**Haptics:** Custom Taptic Engine patterns for phase transitions (e.g., a "double knock" when a break starts).</cite>
- <cite index="1-15">**Widgets:** Home Screen widgets showing the current team status.</cite>

---

## Tech Stack

<cite index="1-17">

| Layer | Technology |
|---|---|
| UI Framework | SwiftUI |
| Concurrency | Swift 6 (Async/Await) |
| Networking | URLSession / WebSockets (for Room Events) |
| Dependency Injection | Native Property Wrappers (`@StateObject`, `@Environment`) |

</cite>

---

*Confidential Technical Document — Teamodoro Project 2026*
