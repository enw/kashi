# ╭─────────────────────────────────────────╮
# │  K A S H I                              │
# │  local-first AI meeting notes · macOS   │
# ╰─────────────────────────────────────────╯

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14.4+-000000?style=flat&logo=apple)](https://www.apple.com/macos/)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-FA7343?style=flat&logo=swift)](https://swift.org)
[![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-ARM64-333333?style=flat&logo=apple)](https://support.apple.com/en-us/HT211814)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=flat)](https://www.apple.com/macos/)
[![Status](https://img.shields.io/badge/status-active-success?style=flat)](https://github.com)

> *Like Granola, but it actually runs on **your** machine. No cloud. No uploads. No excuses.*

---

## 🎯 tl;dr

**Kashi** = live transcription + markdown notes + AI summaries. Everything stays on your Mac. Apple Silicon + WhisperKit + optional Ollama. Your meetings, your data, your rules.

---

## ✨ what you get

| Feature | Description |
|--------|-------------|
| **Live transcription** | Mic + system audio (other participants) via [WhisperKit](https://github.com/argmaxinc/WhisperKit) — **on-device**, no API keys |
| **Speaker labels** | `Me` (mic) vs `Others` (system audio) so you know who said what |
| **Markdown notes** | Side-by-side with the transcript, persisted with [SwiftData](https://developer.apple.com/documentation/swiftdata) |
| **AI summaries** | [Ollama](https://ollama.com) — structured notes, action items, Q&A. **100% local.** |
| **Calendar** | Upcoming meetings in the sidebar (EventKit) |
| **Export** | Copy as Markdown or save to file. No lock-in. |

---

## 📋 requirements

```
macOS    14.4+ (Sonoma or later)
CPU      Apple Silicon (for WhisperKit)
Ollama   optional — brew install ollama && ollama pull llama3.2
```

On first run you’ll be asked for **Microphone** and (if you use calendar) **Calendar**. For capturing *other* people’s audio, the app uses the Core Audio Process Tap API and will request system audio permission when you start a session.

---

## 🚀 build & run

```bash
# 1. Open in Xcode
open Kashi.xcodeproj

# 2. Select scheme: Kashi → My Mac
# 3. ⌘R
```

That’s it. No npm. No containers. No cloud config.

---

## 📖 usage

1. **New meeting** — Sidebar → “New meeting” or start from the detail view.
2. **Start** — Hit **Start** to capture mic + system audio and run live transcription.
3. **Notes** — Type in the Notes panel; markdown supported.
4. **Stop** — **Stop** when you’re done. Meeting is saved automatically.
5. **Summary** — Open meeting → **Summary** tab → pick a template → **Generate summary** (Ollama must be running).
6. **Chat** — **Chat** tab: ask questions about the transcript (Ollama).
7. **Export** — Toolbar **Export** → copy as Markdown or save to file.

---

## ⚙️ settings

**Kashi → Settings** (or `⌘,`):

- Ollama base URL + model
- Whisper model (tiny / base / small / medium — speed vs accuracy)

---

## 📁 project layout

```
Kashi/
├── Models/       TranscriptSegment, Meeting, MeetingTranscriptSegment (SwiftData)
├── Services/      Audio (mic + system tap), WhisperKit, Ollama, calendar, templates
└── Views/        Sidebar, transcript, notes, summary, chat, settings, export
```

---

## 📜 license

**MIT** — see [LICENSE](LICENSE). Ship it, fork it, make it yours.

---

*Built for people who want AI meeting notes without sending their conversations to the cloud. Stay local. Stay in control.*
