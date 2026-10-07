import SwiftUI
import Lottie

// MARK: - Hero

struct TyfeStreakHeroView: View {
    let streakCount: Int
    let state: StreakHeroState

    var body: some View {
        TyfeSurfaceView(role: .streakBoard) {
            VStack(spacing: TyfeSpacing.relatedGap) {
                TyfeStreakFireView(streakCount: streakCount)

                Text(String(streakCount))
                    .font(.system(size: 64, weight: .black, design: .serif))
                    .monospacedDigit()

                Text("DAY STREAK")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.4)

                Text(state.message)
                    .font(TyfeTypography.interface)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current streak")
        .accessibilityValue("\(streakCount) days. \(state.title)")
        .accessibilityIdentifier("streak-hero")
    }
}

/// The animated fire shown in the streak hero. Decorative: the streak number
/// and hero accessibility value carry the real meaning. Falls back to the
/// static growth tiles when Lottie is unavailable or Reduce Motion is on.
struct TyfeStreakFireView: View {
    let streakCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let fireHeight: CGFloat = 88
    private static let fireWidth: CGFloat = fireHeight * (500.0 / 690.0)

    var body: some View {
        Group {
            #if canImport(Lottie)
            if reduceMotion {
                fallback
            } else {
                LottieView(animation: .named("fire"))
                    .playing(loopMode: .loop)
                    .animationSpeed(0.8)
                    .resizable()
                    .frame(width: Self.fireWidth, height: Self.fireHeight)
            }
            #else
            fallback
            #endif
        }
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        TyfeStreakGrowthTilesView(streakCount: streakCount)
    }
}

/// A small staircase of tiles that fills as the streak grows. Decorative:
/// the streak number and hero accessibility value carry the real meaning.
private struct TyfeStreakGrowthTilesView: View {
    let streakCount: Int
    var tint: Color = TyfeEditorialPalette.onBoard

    private let tileCount = 5
    private let tileWidth: CGFloat = 20

    private var filledTileCount: Int {
        switch streakCount {
        case 0: return 0
        case 1...2: return 1
        case 3...6: return 2
        case 7...13: return 3
        case 14...29: return 4
        default: return 5
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: TyfeSpacing.relatedGap) {
            ForEach(0..<tileCount, id: \.self) { index in
                let isFilled = index < filledTileCount
                let height = 20 + CGFloat(index) * 8

                RoundedRectangle(cornerRadius: TyfeSpacing.tightGap)
                    .fill(isFilled ? tint : .clear)
                    .frame(width: tileWidth, height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeSpacing.tightGap)
                            .stroke(
                                isFilled ? tint : tint.opacity(0.3),
                                lineWidth: TyfeStroke.standard
                            )
                    }
            }
        }
        .frame(height: 52)
        .accessibilityHidden(true)
    }
}

// MARK: - Stats

struct TyfeStreakStatsView: View {
    let longestStreak: Int

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                Text("Longest run")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Text("\(longestStreak) days")
                    .font(TyfeTypography.displayCompact)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Longest run")
        .accessibilityValue("\(longestStreak) days")
        .accessibilityIdentifier("streak-stats")
    }
}

// MARK: - Freeze bank

struct TyfeStreakFreezeBankView: View {
    let progress: StreakFreezeProgress
    let guidance: String

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                Text("Freeze bank")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.tightGap) {
                    ForEach(0..<progress.maximum, id: \.self) { index in
                        freezeToken(isFilled: index < progress.available)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Freeze bank")
        .accessibilityValue("\(progress.available) of \(progress.maximum) available")
        .accessibilityHint(guidance)
        .accessibilityIdentifier("streak-freeze-bank")
    }

    private func freezeToken(isFilled: Bool) -> some View {
        RoundedRectangle(cornerRadius: TyfeRadius.control)
            .fill(isFilled ? TyfeEditorialPalette.teal : .clear)
            .frame(width: 24, height: 24)
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(
                        isFilled ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.controlBorder,
                        lineWidth: TyfeStroke.standard
                    )
            }
            .overlay {
                Image(systemName: "snowflake")
                    .font(.caption.weight(.black))
                    .foregroundStyle(
                        isFilled
                            ? TyfeEditorialPalette.onAccent
                            : TyfeEditorialPalette.muted.opacity(0.45)
                    )
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Week trail

struct TyfeStreakWeekTrailView: View {
    let days: [StreakDay]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Text("Last 7 days")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.relatedGap) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        VStack(spacing: TyfeSpacing.tightGap) {
                            Text(day.weekdayInitial)
                                .font(TyfeTypography.caption)
                                .foregroundStyle(
                                    day.isToday ? TyfeEditorialPalette.ink : TyfeEditorialPalette.muted
                                )
                                .accessibilityHidden(true)

                            TyfeStreakDayTile(day: day)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.6)
                        .animation(tileAnimation(index: index), value: hasAppeared)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("streak-week-trail")
        .onAppear {
            hasAppeared = true
        }
    }

    private func tileAnimation(index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(response: 0.36, dampingFraction: 0.74)
            .delay(Double(index) * 0.04)
    }
}

private struct TyfeStreakDayTile: View {
    let day: StreakDay

    var body: some View {
        RoundedRectangle(cornerRadius: TyfeRadius.control)
            .fill(fill)
            .frame(height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(stroke, lineWidth: day.isToday ? TyfeStroke.emphasis : TyfeStroke.standard)
            }
            .overlay {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(foreground)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.accessibilityLabel)
    }

    private var fill: Color {
        switch day.mark {
        case .focus: return TyfeEditorialPalette.success.opacity(0.2)
        case .freeze: return TyfeEditorialPalette.teal.opacity(0.2)
        case .openToday: return TyfeEditorialPalette.saffron
        case .empty, .rest: return .clear
        }
    }

    private var stroke: Color {
        switch day.mark {
        case .focus: return TyfeEditorialPalette.success
        case .freeze: return TyfeEditorialPalette.teal
        case .openToday: return TyfeEditorialPalette.onAccent
        case .empty, .rest: return TyfeEditorialPalette.muted.opacity(0.35)
        }
    }

    private var foreground: Color {
        day.mark == .openToday ? TyfeEditorialPalette.onAccent : stroke
    }

    private var symbolName: String? {
        switch day.mark {
        case .focus: return "checkmark"
        case .freeze: return "snowflake"
        case .openToday: return "circle"
        case .empty: return nil
        case .rest: return "minus"
        }
    }
}

#Preview("Streak components") {
    let days = (0..<7).reversed().map { offset -> StreakDay in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let mark: StreakDayMark = offset == 0 ? .openToday : (offset == 3 ? .freeze : .focus)
        return StreakDay(
            date: date,
            weekdayInitial: "M",
            mark: mark,
            isToday: offset == 0,
            accessibilityLabel: "Preview day"
        )
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
            TyfeStreakHeroView(streakCount: 7, state: .secured)
            HStack(alignment: .top, spacing: TyfeSpacing.relatedGap) {
                TyfeStreakStatsView(longestStreak: 12)
                TyfeStreakFreezeBankView(
                    progress: StreakFreezeProgress(available: 2, maximum: 3),
                    guidance: StreakFreezePolicy.guidance
                )
            }
            TyfeStreakWeekTrailView(days: days)
        }
        .padding(TyfeSpacing.screenInset)
    }
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Narrow streak cards") {
    HStack(alignment: .top, spacing: TyfeSpacing.relatedGap) {
        TyfeStreakStatsView(longestStreak: 120)
        TyfeStreakFreezeBankView(
            progress: StreakFreezeProgress(available: 2, maximum: 3),
            guidance: StreakFreezePolicy.guidance
        )
    }
    .padding(TyfeSpacing.screenInset)
    .frame(width: 320)
    .background(TyfeEditorialPalette.canvas)
}
