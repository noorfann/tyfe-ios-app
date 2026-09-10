import SwiftUI

struct TyfeActivityCardView: View {
    let activity: ActivityModel
    let sessionCount: Int
    let timeBlock: PlanTimeBlockModel?
    let onStart: () -> Void

    private var accent: Color {
        switch activity.colorToken {
        case "teal": return TyfeEditorialPalette.teal
        case "slateBlue": return TyfeEditorialPalette.slateBlue
        case "saffron": return TyfeEditorialPalette.saffron
        case "terracotta": return TyfeEditorialPalette.terracotta
        default: return TyfeEditorialPalette.focus
        }
    }

    private var scheduleLabel: String {
        guard let plannedStart = timeBlock?.plannedStart else { return "Flexible time" }
        return plannedStart.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .top, spacing: TyfeSpacing.control) {
                    RoundedRectangle(cornerRadius: TyfeRadius.control)
                        .fill(accent)
                        .frame(width: 48, height: 48)
                        .overlay {
                            RoundedRectangle(cornerRadius: TyfeRadius.control)
                                .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
                            Image(systemName: activity.iconToken ?? "square.grid.2x2")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(TyfeEditorialPalette.onAccent)
                        }
                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text(activity.name)
                            .font(TyfeTypography.interfaceStrong)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(sessionCount) \(sessionCount == 1 ? "session" : "sessions") · \(scheduleLabel)")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }
                TyfeActionButtonView(title: "Start Focus", systemImage: "play.fill", onTap: onStart)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Activity, \(activity.name)"))
        .accessibilityValue(Text("\(sessionCount) planned \(sessionCount == 1 ? "session" : "sessions"), \(scheduleLabel)"))
    }
}

#Preview("Activity cards") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeActivityCardView(activity: .mock, sessionCount: 1, timeBlock: nil) {}
        TyfeActivityCardView(
            activity: ActivityModel.mocks[1],
            sessionCount: 2,
            timeBlock: DailyPlanModel.timedMock.timeBlocks?.first
        ) {}
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
