import SwiftUI

/// Animated continuation of the system launch screen.
struct SplashView: View {
    @State private var visiblePairCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onCompleted: () -> Void

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            ZStack {
                brandLayer(.logo)

                brandLayer(.focus)
                    .scaleEffect(scale(for: 1), anchor: .init(x: 0.25, y: 0.66))
                    .opacity(visiblePairCount >= 1 ? 1 : 0)

                brandLayer(.earn)
                    .scaleEffect(scale(for: 2), anchor: .init(x: 0.5, y: 0.66))
                    .opacity(visiblePairCount >= 2 ? 1 : 0)

                brandLayer(.rest)
                    .scaleEffect(scale(for: 3), anchor: .init(x: 0.75, y: 0.66))
                    .opacity(visiblePairCount >= 3 ? 1 : 0)
            }
            .frame(width: 260, height: 220)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("tyfe. Focus. Earn. Rest.")
        .accessibilityIdentifier("manualSplash")
        .task {
            for pairCount in 1...3 {
                withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .spring(duration: 0.5, bounce: 0.35)) {
                    visiblePairCount = pairCount
                }
                do {
                    try await Task.sleep(for: .milliseconds(800))
                } catch {
                    return
                }
            }
            onCompleted()
        }
    }

    private func brandLayer(_ part: LaunchBrandPart) -> some View {
        Image("LaunchBrand")
            .resizable()
            .frame(width: 260, height: 220)
            .mask(LaunchBrandMask(part: part))
    }

    private func scale(for pairNumber: Int) -> CGFloat {
        (reduceMotion || visiblePairCount >= pairNumber) ? 1 : 0.7
    }
}

private enum LaunchBrandPart {
    case logo
    case focus
    case earn
    case rest
}

/// Rectangles fall entirely in transparent gaps of the original 260 × 220 artwork.
private struct LaunchBrandMask: Shape {
    let part: LaunchBrandPart

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 260
        let scaleY = rect.height / 220
        let regions: [CGRect]

        switch part {
        case .logo:
            regions = [CGRect(x: 0, y: 0, width: 260, height: 90)]
        case .focus:
            regions = [
                CGRect(x: 0, y: 90, width: 114, height: 35),
                CGRect(x: 0, y: 125, width: 98, height: 95)
            ]
        case .earn:
            regions = [
                CGRect(x: 114, y: 90, width: 43, height: 35),
                CGRect(x: 98, y: 125, width: 64, height: 95)
            ]
        case .rest:
            regions = [
                CGRect(x: 157, y: 90, width: 103, height: 35),
                CGRect(x: 162, y: 125, width: 98, height: 95)
            ]
        }

        var path = Path()
        for region in regions {
            path.addRect(CGRect(
                x: region.minX * scaleX,
                y: region.minY * scaleY,
                width: region.width * scaleX,
                height: region.height * scaleY
            ))
        }
        return path
    }
}
