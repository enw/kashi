import SwiftUI

/// Renders a markdown string as formatted text (headings, lists, bold, etc.) using
/// Foundation's AttributedString. Falls back to plain text if parsing fails.
struct MarkdownTextView: View {
    let markdown: String

    var body: some View {
        if markdown.isEmpty {
            Text("")
        } else if let attributed = parsedAttributedString {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(markdown)
                .textSelection(.enabled)
        }
    }

    private var parsedAttributedString: AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        guard let raw = try? AttributedString(markdown: markdown, options: options) else {
            return nil
        }
        return Self.applyPresentationIntentStyling(to: raw)
    }

    /// Applies font styling to header and list runs, and inserts paragraph breaks so
    /// block-level content doesn't render as one run-on line (full markdown parsing strips newlines).
    private static func applyPresentationIntentStyling(to attr: AttributedString) -> AttributedString {
        var result = attr
        let intentAttribute = AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self

        // 1. Apply font styling (reverse order so ranges stay valid)
        for (intentValue, range) in result.runs[intentAttribute].reversed() {
            guard let intent = intentValue else { continue }
            for component in intent.components {
                switch component.kind {
                case .header(level: let level):
                    let font: Font = switch level {
                    case 1: .title
                    case 2: .title2
                    case 3: .title3
                    default: .headline
                    }
                    result[range].font = font
                case .unorderedList, .orderedList:
                    result[range].font = .body
                default:
                    break
                }
            }
        }

        // 2. Insert paragraph breaks between block-level runs (in reverse order so indices stay valid)
        let orderedRuns = result.runs[intentAttribute].sorted { a, b in
            a.1.lowerBound < b.1.lowerBound
        }
        let paragraphBreak = AttributedString("\n\n")
        for i in (1 ..< orderedRuns.count).reversed() {
            let insertPosition = orderedRuns[i].1.lowerBound
            result.insert(paragraphBreak, at: insertPosition)
        }
        return result
    }
}

#Preview {
    MarkdownTextView(markdown: """
    ### Meeting Notes
    #### Summary
    We discussed the thing.
    #### Key Decisions
    - To test "the thing."
    - Responsibilities assigned to Kelly.
    #### Action Items
    - Kelly: Test "the thing."
    """)
    .frame(width: 400, height: 300)
    .padding()
}
