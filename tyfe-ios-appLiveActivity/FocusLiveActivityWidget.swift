import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TyfeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FocusLiveActivityWidget()
    }
}

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            FocusLiveActivityLockScreenView(context: context)
                .widgetURL(FocusLiveActivityRoute.url(sessionId: context.attributes.focusSessionId))
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FocusLiveActivityBrandView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        FocusLiveActivityProgressRingView(state: context.state)
                            .frame(width: 22, height: 22)
                        FocusLiveActivityTimerView(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FocusLiveActivityStatusView(state: context.state)
                }
            } compactLeading: {
                FocusLiveActivityProgressRingView(state: context.state)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                FocusLiveActivityTimerView(state: context.state)
            } minimal: {
                FocusLiveActivityLogoView()
            }
            .widgetURL(FocusLiveActivityRoute.url(sessionId: context.attributes.focusSessionId))
        }
    }
}

private struct FocusLiveActivityLockScreenView: View {
    let context: ActivityViewContext<FocusLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                FocusLiveActivityBrandView()
                FocusLiveActivityStatusView(state: context.state)
                    .font(.subheadline)
            }

            Spacer(minLength: 8)
            HStack(spacing: 8) {
                FocusLiveActivityProgressRingView(state: context.state)
                    .frame(width: 28, height: 28)
                FocusLiveActivityTimerView(state: context.state)
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
            }
        }
        .padding()
    }
}

private struct FocusLiveActivityBrandView: View {
    var body: some View {
        HStack(spacing: 6) {
            FocusLiveActivityLogoView()
            Text("Tyfe")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

private struct FocusLiveActivityLogoView: View {
    var body: some View {
        Image("TyfeLogo", bundle: .main)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct FocusLiveActivityProgressRingView: View {
    let state: FocusLiveActivityAttributes.ContentState

    var body: some View {
        if state.phase == .running {
            ProgressView(
                timerInterval: state.startedAt...state.endsAt,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.circular)
            .tint(FocusLiveActivityPalette.accent)
            .accessibilityLabel("Focus progress")
        }
    }
}

private enum FocusLiveActivityPalette {
    static let accent = Color(red: 0.4, green: 0.75, blue: 0.74)
}

private struct FocusLiveActivityTimerView: View {
    let state: FocusLiveActivityAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.startedAt...state.endsAt,
            countsDown: true,
            showsHours: false
        )
        .monospacedDigit()
    }
}

private struct FocusLiveActivityStatusView: View {
    let state: FocusLiveActivityAttributes.ContentState

    var body: some View {
        Text(statusTitle)
    }

    private var statusTitle: String {
        switch state.phase {
        case .running: "Focusing"
        case .completed: "Session complete"
        case .abandoned: "Session ended"
        }
    }
}

private enum FocusLiveActivityRoute {
    static func url(sessionId: String) -> URL {
        var components = URLComponents()
        components.scheme = "tyfe"
        components.host = "focus"
        components.queryItems = [URLQueryItem(name: "sessionId", value: sessionId)]
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
