import SwiftUI

struct NoteEditorView: View {
    @Binding var text: String
    var placeholder: String = "Add notes (markdown supported: **bold**, *italic*, - bullets, # headers)…"

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(8)
    }
}

#Preview {
    NoteEditorView(text: .constant(""))
        .frame(width: 300, height: 200)
}
