import SwiftUI

struct SettingsView: View {
    @AppStorage("ollamaBaseURL") private var ollamaBaseURL = "http://localhost:11434"
    @AppStorage("ollamaModel") private var ollamaModel = "llama3.2"
    @AppStorage("whisperModel") private var whisperModel = "base.en"

    var body: some View {
        Form {
            Section("Ollama") {
                TextField("Base URL", text: $ollamaBaseURL)
                TextField("Model", text: $ollamaModel)
            }
            Section("Transcription") {
                Picker("Whisper model", selection: $whisperModel) {
                    Text("Tiny (fast)").tag("tiny.en")
                    Text("Base (balanced)").tag("base.en")
                    Text("Small").tag("small.en")
                    Text("Medium").tag("medium.en")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 220)
    }
}
