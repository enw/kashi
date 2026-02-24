import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                usage
                summaryAndChat
                export
                settings
                requirements
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
        .frame(minWidth: 400, minHeight: 480)
    }

    private var header: some View {
        HStack(spacing: 12) {
            KashiLogoView(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Kashi")
                    .font(.title.bold())
                Text("Local-first AI meeting notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
    }

    private var usage: some View {
        section("Usage") {
            step("New meeting", "Click “New meeting” in the sidebar or start recording from the detail view.")
            step("Start", "Click **Start** to capture mic + system audio and live transcription.")
            step("Notes", "Type in the Notes panel; Markdown is supported.")
            step("Stop", "Click **Stop** when the meeting ends. The meeting is saved automatically.")
        }
    }

    private var summaryAndChat: some View {
        section("Summary & Chat") {
            Text("Open a meeting, go to the **Summary** tab, choose a template, and click **Generate summary** (requires Ollama).")
            Text("In the **Chat** tab you can ask questions about the transcript (Ollama).")
        }
    }

    private var export: some View {
        section("Export") {
            Text("Use the toolbar **Export** menu to copy as Markdown or save to a file.")
        }
    }

    private var settings: some View {
        section("Settings") {
            Text("**Kashi → Settings** (⌘,) — set Ollama base URL and model, and the Whisper model (tiny/base/small/medium).")
        }
    }

    private var requirements: some View {
        section("Requirements") {
            bullet("macOS 14.4+ (Sonoma or later)")
            bullet("Apple Silicon (for WhisperKit)")
            bullet("Ollama (optional): install with `brew install ollama`, then `ollama pull llama3.2`")
        }
        .padding(.bottom, 20)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func step(_ label: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .fontWeight(.medium)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HelpView()
        .frame(width: 440, height: 560)
}
