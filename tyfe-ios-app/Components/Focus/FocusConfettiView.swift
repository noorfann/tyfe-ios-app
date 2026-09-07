import SwiftUI

struct FocusConfettiView: View {

    @State private var hasStarted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(FocusConfettiPiece.all) { piece in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(hasStarted ? piece.endRotation : piece.startRotation))
                        .position(
                            x: proxy.size.width * piece.horizontalPosition + (hasStarted ? piece.drift : 0),
                            y: hasStarted ? proxy.size.height * 1.08 : proxy.size.height * piece.startY
                        )
                        .opacity(hasStarted ? 0 : 1)
                        .animation(
                            .easeIn(duration: 1.15).delay(piece.delay),
                            value: hasStarted
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            hasStarted = true
        }
    }
}

private struct FocusConfettiPiece: Identifiable {

    let id: Int
    let horizontalPosition: CGFloat
    let startY: CGFloat
    let drift: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let startRotation: Double
    let endRotation: Double
    let delay: Double

    static let all: [FocusConfettiPiece] = [
        .init(id: 0, horizontalPosition: 0.08, startY: 0.08, drift: 34, width: 9, height: 18, color: TyfeEditorialPalette.focus, startRotation: -12, endRotation: 240, delay: 0.00),
        .init(id: 1, horizontalPosition: 0.17, startY: 0.18, drift: -22, width: 7, height: 14, color: TyfeEditorialPalette.teal, startRotation: 18, endRotation: -210, delay: 0.08),
        .init(id: 2, horizontalPosition: 0.26, startY: 0.04, drift: 28, width: 10, height: 6, color: TyfeEditorialPalette.saffron, startRotation: 35, endRotation: 290, delay: 0.16),
        .init(id: 3, horizontalPosition: 0.35, startY: 0.14, drift: -30, width: 8, height: 16, color: TyfeEditorialPalette.terracotta, startRotation: -26, endRotation: -260, delay: 0.04),
        .init(id: 4, horizontalPosition: 0.44, startY: 0.02, drift: 18, width: 7, height: 12, color: TyfeEditorialPalette.slateBlue, startRotation: 12, endRotation: 190, delay: 0.12),
        .init(id: 5, horizontalPosition: 0.53, startY: 0.16, drift: -34, width: 10, height: 6, color: TyfeEditorialPalette.focus, startRotation: -18, endRotation: -230, delay: 0.20),
        .init(id: 6, horizontalPosition: 0.62, startY: 0.06, drift: 26, width: 8, height: 17, color: TyfeEditorialPalette.teal, startRotation: 28, endRotation: 270, delay: 0.06),
        .init(id: 7, horizontalPosition: 0.71, startY: 0.13, drift: -20, width: 9, height: 8, color: TyfeEditorialPalette.saffron, startRotation: -8, endRotation: -180, delay: 0.18),
        .init(id: 8, horizontalPosition: 0.80, startY: 0.03, drift: 32, width: 7, height: 15, color: TyfeEditorialPalette.terracotta, startRotation: 20, endRotation: 220, delay: 0.10),
        .init(id: 9, horizontalPosition: 0.90, startY: 0.17, drift: -28, width: 10, height: 6, color: TyfeEditorialPalette.slateBlue, startRotation: -32, endRotation: -280, delay: 0.02),
        .init(id: 10, horizontalPosition: 0.13, startY: 0.26, drift: 20, width: 8, height: 13, color: TyfeEditorialPalette.saffron, startRotation: 8, endRotation: 250, delay: 0.24),
        .init(id: 11, horizontalPosition: 0.31, startY: 0.23, drift: -26, width: 9, height: 7, color: TyfeEditorialPalette.focus, startRotation: -20, endRotation: -200, delay: 0.14),
        .init(id: 12, horizontalPosition: 0.50, startY: 0.28, drift: 30, width: 7, height: 16, color: TyfeEditorialPalette.teal, startRotation: 24, endRotation: 300, delay: 0.22),
        .init(id: 13, horizontalPosition: 0.69, startY: 0.24, drift: -18, width: 10, height: 6, color: TyfeEditorialPalette.terracotta, startRotation: -14, endRotation: -240, delay: 0.26),
        .init(id: 14, horizontalPosition: 0.86, startY: 0.27, drift: 24, width: 8, height: 14, color: TyfeEditorialPalette.focus, startRotation: 32, endRotation: 210, delay: 0.16)
    ]
}
