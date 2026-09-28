import ActivityKit
import SwiftUI
import WidgetKit

struct RewardLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RewardLiveActivityAttributes.self) { context in
            RewardLiveActivityLockScreenView(context: context)
                .widgetURL(RewardLiveActivityRoute.url(claimId: context.attributes.rewardClaimId))
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RewardLiveActivityBrandView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 6) {
                        RewardLiveActivityProgressRingView(state: context.state)
                            .frame(width: 22, height: 22)
                        RewardLiveActivityTimerView(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        RewardLiveActivityTitleView(title: context.attributes.rewardTitle)
                        RewardLiveActivityStatusView(state: context.state)
                            .font(.subheadline)
                    }
                }
            } compactLeading: {
                RewardLiveActivityProgressRingView(state: context.state)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                RewardLiveActivityTimerView(state: context.state)
            } minimal: {
                RewardLiveActivityLogoView()
            }
            .widgetURL(RewardLiveActivityRoute.url(claimId: context.attributes.rewardClaimId))
        }
    }
}

private struct RewardLiveActivityLockScreenView: View {
    let context: ActivityViewContext<RewardLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    RewardLiveActivityLogoView()
                    RewardLiveActivityTitleView(title: context.attributes.rewardTitle)
                }
                RewardLiveActivityStatusView(state: context.state)
                    .font(.subheadline)
            }

            Spacer(minLength: 8)
            HStack(spacing: 8) {
                RewardLiveActivityProgressRingView(state: context.state)
                    .frame(width: 28, height: 28)
                RewardLiveActivityTimerView(state: context.state)
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
            }
        }
        .padding()
    }
}

private struct RewardLiveActivityBrandView: View {
    var body: some View {
        HStack(spacing: 6) {
            RewardLiveActivityLogoView()
            Text("Tyfe")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

private struct RewardLiveActivityTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RewardLiveActivityLogoView: View {
    var body: some View {
        Image("TyfeLogo", bundle: .main)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct RewardLiveActivityProgressRingView: View {
    let state: RewardLiveActivityAttributes.ContentState

    var body: some View {
        if state.phase == .active {
            ProgressView(
                timerInterval: state.startedAt...state.endsAt,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.circular)
            .tint(RewardLiveActivityPalette.accent)
            .accessibilityLabel("Reward progress")
        }
    }
}

private enum RewardLiveActivityPalette {
    static let accent = Color(red: 0.867, green: 0.631, blue: 0.227)
}

private struct RewardLiveActivityTimerView: View {
    let state: RewardLiveActivityAttributes.ContentState

    var body: some View {
        Text(
            timerInterval: state.startedAt...state.endsAt,
            countsDown: true,
            showsHours: false
        )
        .monospacedDigit()
    }
}

private struct RewardLiveActivityStatusView: View {
    let state: RewardLiveActivityAttributes.ContentState

    var body: some View {
        Text(statusTitle)
    }

    private var statusTitle: String {
        switch state.phase {
        case .active: "Reward time"
        case .expired: "Reward complete"
        }
    }
}

private enum RewardLiveActivityRoute {
    static func url(claimId: String) -> URL {
        var components = URLComponents()
        components.scheme = "tyfe"
        components.host = "rewards"
        components.queryItems = [URLQueryItem(name: "claimId", value: claimId)]
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
