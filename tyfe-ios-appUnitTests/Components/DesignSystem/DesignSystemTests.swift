import SwiftUI
import Testing
@testable import tyfe_ios_app

struct DesignSystemTests {

    @Test func primitiveComponentsAcceptInjectedData() {
        let surface = TyfeSurfaceView(role: .paper) {
            Text("Surface")
        }
        let action = TyfeActionButtonView(
            title: "Start",
            systemImage: "play.fill",
            role: .primary,
            onTap: {}
        )
        let pill = TyfePillView(
            label: "Focusing",
            systemImage: "timer",
            tone: .success
        )
        let metric = TyfeMetricCardView(
            title: "Credits",
            value: "2",
            detail: "available",
            systemImage: "circle.fill",
            accent: TyfeEditorialPalette.saffron
        )
        let progress = TyfeProgressBarView(label: "XP", current: 40, total: 100)
        let badge = TyfeStateBadgeView(state: .paused)

        _ = Group {
            surface
            action
            pill
            metric
            progress
            badge
        }
    }

    @Test func phaseOneComponentsAcceptDomainFixtures() {
        let activity = TyfeActivityCardView(
            activity: .mock,
            sessionCount: 1,
            timeBlock: nil,
            onStart: {}
        )
        let timer = TyfeFocusTimerView(
            session: .pausedMock,
            activityTitle: "Study Swift",
            timeText: "04:32",
            onBegin: {},
            onPause: {},
            onResume: {},
            onAbandon: {}
        )
        let progression = TyfeProgressionCardView(progression: .mock)
        let status = TyfeStatusView(kind: .offline, onRetry: {})
        let motif = TyfeMotifView(kind: .completion)

        _ = Group {
            activity
            timer
            progression
            status
            motif
        }
    }

    @Test func rewardsComponentsAcceptDomainFixtures() {
        let reward = TyfeRewardCardView(reward: .mock, balance: 2, onTap: {})
        let readyClaim = TyfeClaimCardView(
            claim: .mock,
            remainingSeconds: 0,
            endText: "3:05 PM",
            onStart: {}
        )
        let activeClaim = TyfeClaimCardView(
            claim: .activeMock,
            remainingSeconds: 300,
            endText: "3:05 PM",
            onStart: {}
        )
        let tiers = TyfeTierLegendView()
        let statusBar = TyfeRewardStatusBarView(
            title: "Reward in progress",
            timeText: "12:30",
            systemImage: "clock.fill"
        )

        _ = Group {
            reward
            readyClaim
            activeClaim
            tiers
            statusBar
        }
    }
}
