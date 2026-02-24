# Kashi

A local-first AI meeting notes app for macOS — like Granola, but everything runs on your Mac.

## Features

- **Live transcription** from your microphone and system audio (other participants) using [WhisperKit](https://github.com/argmaxinc/WhisperKit) (on-device, Apple Silicon).
- **Speaker labels**: “Me” (mic) vs “Others” (system audio) in the transcript.
- **Markdown notes** alongside the transcript, persisted with [SwiftData](https://developer.apple.com/documentation/swiftdata).
- **AI summaries** via [Ollama](https://ollama.com): structured notes, action items, and Q&A over the transcript (optional, fully local).
- **Calendar** (EventKit): upcoming meetings in the sidebar.
- **Export**: copy as Markdown or save to file.

## Requirements

- **macOS 14.4+** (Sonoma or later)
- **Apple Silicon** (for WhisperKit)
- **Ollama** (optional): install with `brew install ollama`, then `ollama pull llama3.2` (or another model).

## Build and run

1. Open `Kashi.xcodeproj` in Xcode.
2. Select the **Kashi** scheme and a **My Mac** destination.
3. Build and run (⌘R).

On first run, allow **Microphone** and (if you use calendar) **Calendar** access. For system audio capture (others’ voices), the app uses the Core Audio Process Tap API and will prompt for system audio permission when you start a session.

## Usage

1. **New meeting** — In the sidebar, click “New meeting” or start recording from the detail view.
2. **Start** — Click **Start** to begin capturing mic + system audio and live transcription.
3. **Notes** — Type in the Notes panel; markdown is supported.
4. **Stop** — Click **Stop** when the meeting ends. The meeting is saved automatically.
5. **Summary** — Open the meeting, go to the **Summary** tab, choose a template, and click **Generate summary** (requires Ollama running).
6. **Chat** — In the **Chat** tab, ask questions about the transcript (Ollama).
7. **Export** — Use the toolbar **Export** menu to copy as Markdown or save to a file.

## Settings

**Kashi → Settings** (or ⌘,) lets you set:

- Ollama base URL and model
- Whisper model (tiny/base/small/medium for speed vs accuracy)

## Project structure

- **Kashi/** — App target
  - **Models/** — `TranscriptSegment`, `Meeting`, `MeetingTranscriptSegment` (SwiftData)
  - **Services/** — Audio (mic + system tap), WhisperKit transcription, Ollama, calendar, templates
  - **Views/** — Sidebar, transcript, notes, summary, chat, settings, export

## License

MIT License — see [LICENSE](LICENSE).
