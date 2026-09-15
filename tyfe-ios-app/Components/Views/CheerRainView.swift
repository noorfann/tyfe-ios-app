import SwiftUI

struct CheerRainView: View {

    var kinds: [CheerKind] = [.clap]
    var onCompleted: () -> Void = { }
    var reduceMotionOverride: Bool?

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var hasStarted = false

    private let particleCount = 20
    private let animationDuration = 1.5

    var body: some View {
        Group {
            if reduceMotionOverride ?? accessibilityReduceMotion {
                staticBadge
            } else {
                emojiRain
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            do {
                try await Task.sleep(for: .seconds(animationDuration))
            } catch {
                return
            }
            onCompleted()
        }
    }

    private var emojiRain: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    Text(emoji(for: index))
                        .font(index.isMultiple(of: 3) ? .largeTitle : .title)
                        .rotationEffect(.degrees(hasStarted ? endRotation(for: index) : startRotation(for: index)))
                        .position(
                            x: horizontalPosition(for: index, width: proxy.size.width)
                                + (hasStarted ? horizontalDrift(for: index) : 0),
                            y: hasStarted ? proxy.size.height + 48 : startingHeight(for: index)
                        )
                        .opacity(hasStarted ? 0 : 1)
                        .animation(
                            .easeIn(duration: 1.2).delay(particleDelay(for: index)),
                            value: hasStarted
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            hasStarted = true
        }
    }

    private var staticBadge: some View {
        HStack(spacing: 8) {
            ForEach(uniqueKinds, id: \.self) { kind in
                Text(kind.emoji)
                    .font(.largeTitle)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var availableKinds: [CheerKind] {
        kinds.isEmpty ? [.clap] : kinds
    }

    private var uniqueKinds: [CheerKind] {
        CheerKind.allCases.filter(availableKinds.contains)
    }

    private func emoji(for index: Int) -> String {
        availableKinds[index % availableKinds.count].emoji
    }

    private func horizontalPosition(for index: Int, width: CGFloat) -> CGFloat {
        let fraction = CGFloat((index * 37 + 11) % 100) / 100
        return width * (0.06 + fraction * 0.88)
    }

    private func startingHeight(for index: Int) -> CGFloat {
        -32 - CGFloat((index * 19) % 90)
    }

    private func horizontalDrift(for index: Int) -> CGFloat {
        CGFloat((index * 29) % 81 - 40)
    }

    private func startRotation(for index: Int) -> Double {
        Double((index * 17) % 50 - 25)
    }

    private func endRotation(for index: Int) -> Double {
        let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
        return direction * Double(180 + (index * 31) % 180)
    }

    private func particleDelay(for index: Int) -> Double {
        Double(index % 6) * 0.05
    }
}

#Preview("Single Cheer") {
    CheerRainView(kinds: [.heart])
        .background(TyfeEditorialPalette.canvas)
}

#Preview("Mixed Cheers") {
    CheerRainView(kinds: [.clap, .heart, .fire, .star])
        .background(TyfeEditorialPalette.navy)
}

#Preview("Reduce Motion") {
    CheerRainView(kinds: [.heart, .fire], reduceMotionOverride: true)
        .background(TyfeEditorialPalette.canvas)
}
