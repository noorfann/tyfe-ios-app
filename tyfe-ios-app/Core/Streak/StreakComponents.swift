import SwiftUI
import Lottie

// MARK: - Hero

struct TyfeStreakHeroView: View {
    let streakCount: Int
    let state: StreakHeroState

    var body: some View {
        TyfeSurfaceView(role: .streakBoard) {
            VStack(spacing: TyfeSpacing.small) {
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
        HStack(alignment: .bottom, spacing: TyfeSpacing.small) {
            ForEach(0..<tileCount, id: \.self) { index in
                let isFilled = index < filledTileCount
                let height = 20 + CGFloat(index) * 8

                RoundedRectangle(cornerRadius: TyfeSpacing.unit)
                    .fill(isFilled ? tint : .clear)
                    .frame(width: tileWidth, height: height)
                    .overlay {
                        RoundedRectangle(cornerRadius: TyfeSpacing.unit)
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
    let totalStreakDays: Int
    let bestChaseText: String?
    let lastActiveText: String?

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                if let bestChaseText {
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "trophy.fill")
                            .imageScale(.small)
                            .foregroundStyle(TyfeEditorialPalette.saffron)
                            .accessibilityHidden(true)

                        Text(bestChaseText)
                            .font(TyfeTypography.interface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: TyfeSpacing.control) {
                    TyfeStreakStatItem(title: "Longest", value: String(longestStreak), detail: "days")
                    TyfeStreakStatItem(title: "All time", value: String(totalStreakDays), detail: "days")
                }

                if let lastActiveText {
                    Rectangle()
                        .fill(TyfeEditorialPalette.border)
                        .frame(height: TyfeStroke.hairline)

                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(TyfeEditorialPalette.success)
                            .accessibilityHidden(true)

                        Text(lastActiveText)
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("streak-stats")
    }
}

private struct TyfeStreakStatItem: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
            Text(title)
                .font(TyfeTypography.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(TyfeEditorialPalette.muted)

            HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.unit) {
                Text(value)
                    .font(TyfeTypography.displayCompact)
                    .monospacedDigit()

                Text(detail)
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value) \(detail)")
    }
}

// MARK: - Freeze bank

struct TyfeStreakFreezeBankView: View {
    let progress: StreakFreezeProgress
    let guidance: String

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Freeze bank")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.small) {
                    ForEach(0..<progress.maximum, id: \.self) { index in
                        freezeToken(isFilled: index < progress.available)
                    }
                }

                Text(progress.statusText)
                    .font(TyfeTypography.interface)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Freeze bank")
        .accessibilityValue("\(progress.available) of \(progress.maximum) available. \(progress.statusText)")
        .accessibilityHint(guidance)
        .accessibilityIdentifier("streak-freeze-bank")
    }

    private func freezeToken(isFilled: Bool) -> some View {
        RoundedRectangle(cornerRadius: TyfeRadius.control)
            .fill(isFilled ? TyfeEditorialPalette.teal : .clear)
            .frame(width: 40, height: 40)
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(
                        isFilled ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.controlBorder,
                        lineWidth: TyfeStroke.standard
                    )
            }
            .overlay {
                Image(systemName: "snowflake")
                    .font(.headline.weight(.black))
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
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text("Last 7 days")
                    .font(TyfeTypography.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(spacing: TyfeSpacing.small) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        VStack(spacing: TyfeSpacing.unit) {
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
        case .empty: return .clear
        }
    }

    private var stroke: Color {
        switch day.mark {
        case .focus: return TyfeEditorialPalette.success
        case .freeze: return TyfeEditorialPalette.teal
        case .openToday: return TyfeEditorialPalette.onAccent
        case .empty: return TyfeEditorialPalette.muted.opacity(0.35)
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
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeStreakHeroView(streakCount: 7, state: .secured)
            TyfeStreakStatsView(
                longestStreak: 12,
                totalStreakDays: 34,
                bestChaseText: "5 days from your best of 12.",
                lastActiveText: "Last active 3 Sep 2026"
            )
            TyfeStreakFreezeBankView(
                progress: StreakFreezeProgress(available: 2, maximum: 3, daysUntilNextFreeze: 4),
                guidance: StreakFreezePolicy.guidance
            )
            TyfeStreakWeekTrailView(days: days)
        }
        .padding(TyfeSpacing.control)
    }
    .background(TyfeEditorialPalette.canvas)
}
