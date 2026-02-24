import SwiftUI

/// A bold, modern "K" logo for Kashi — vertical stem with a diagonal kick.
struct KashiLogoView: View {
    var size: CGFloat = 32
    var color: Color = .accentColor

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let stroke: CGFloat = max(2, min(w, h) * 0.24)
            let inset: CGFloat = stroke * 0.6
            let style = StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)

            // Vertical stem (left)
            let stemRect = CGRect(x: inset, y: inset, width: stroke, height: h - inset * 2)
            context.fill(Path(roundedRect: stemRect, cornerRadius: stroke / 2.5), with: .color(color))

            // Top diagonal (upper right arm)
            let topStart = CGPoint(x: inset + stroke, y: inset + stroke * 0.3)
            let topEnd = CGPoint(x: w - inset, y: h * 0.36)
            var topPath = Path()
            topPath.move(to: topStart)
            topPath.addLine(to: topEnd)
            context.stroke(topPath, with: .color(color), style: style)

            // Bottom diagonal (lower right arm)
            let botStart = CGPoint(x: inset + stroke, y: h - inset - stroke * 0.3)
            let botEnd = CGPoint(x: w - inset, y: h * 0.64)
            var botPath = Path()
            botPath.move(to: botStart)
            botPath.addLine(to: botEnd)
            context.stroke(botPath, with: .color(color), style: style)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 24) {
        KashiLogoView(size: 24)
        KashiLogoView(size: 32)
        KashiLogoView(size: 48, color: .blue)
    }
    .padding()
}
