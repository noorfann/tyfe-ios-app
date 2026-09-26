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
        let badge = TyfeStateBadgeView(state: .running)
        let focusStatusPill = TyfeFocusStatusPillView(status: .focusing)
        let bottomSheet = TyfeBottomSheet(
            title: "New Reward",
            onClose: {},
            content: {
                Text("Sheet content")
            }
        )
        let coachmark = TyfeCoachmarkView(
            title: "More activities",
            message: "Swipe to move between them.",
            systemImage: "rectangle.stack.fill",
            onDismiss: {}
        )

        _ = Group {
            surface
            action
            pill
            metric
            badge
            focusStatusPill
            bottomSheet
            coachmark
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
            session: .runningMock,
            daypart: .afternoon,
            activityTitle: "Study Swift",
            timeText: "04:32",
            progress: 0.91,
            supportingText: "Phone lock will not stop the timer",
            onBegin: {},
            onAbandon: {}
        )
        let restTimer = TyfeRestTimerView(
            daypart: .afternoon,
            timeText: "04:12",
            progress: 0.84,
            onSkip: {},
            onBackToToday: {}
        )
        let timerDial = TyfeTimerDialView(
            timeText: "04:12",
            caption: "5 MINUTES",
            progress: 0.84,
            accent: FocusDaypart.afternoon.visualStyle.accentFill,
            primaryForeground: FocusDaypart.afternoon.visualStyle.primaryForeground,
            secondaryForeground: FocusDaypart.afternoon.visualStyle.secondaryForeground,
            accessibilityLabel: "Rest timer",
            accessibilityValue: "04:12"
        )
        let status = TyfeStatusView(kind: .offline, onRetry: {})
        let motif = TyfeMotifView(kind: .completion)

        _ = Group {
            activity
            timer
            restTimer
            timerDial
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
        let coupon = TyfeCouponShape(tearOffset: 92)
        let statusBar = TyfeProgressStatusBarView(
            title: "Reward in progress",
            timeText: "12:30",
            systemImage: "clock.fill",
            accent: TyfeEditorialPalette.saffron,
            accessibilityHint: "Opens Rewards.",
            accessibilityIdentifier: "reward-in-progress-status"
        )

        _ = Group {
            reward
            readyClaim
            activeClaim
            tiers
            coupon
            statusBar
        }
    }

    @Test func circlesCardsAcceptDomainFixtures() {
        let enable = TyfeCircleEnableCardView(onEnable: {})
        let pills = TyfeCirclePillRowView(
            circles: [CircleModel(circleId: "c1", name: "Family", ownerId: "u1", createdAt: .now, updatedAt: .now)],
            selectedCircleId: "c1",
            onSelect: { _ in }
        )
        let invite = TyfeCircleInviteCardView(code: "ABCD2345")
        let sheet = TyfeCircleNameSheetCardView(
            label: "Circle name",
            placeholder: "Family",
            value: .constant(""),
            actionTitle: "Create Circle",
            onSave: {}
        )
        let error = TyfeCircleErrorCardView(message: "Expired", onDismiss: {})

        _ = Group {
            enable
            pills
            invite
            sheet
            error
        }
    }

    @Test func circleMemberRowAcceptsDomainFixtures() {
        let member = CircleMemberModel(
            userId: "u2",
            displayName: "Alex",
            avatarToken: nil,
            role: .member,
            joinedAt: .now
        )
        let progress = CircleMemberProgressModel(
            circleId: "c1",
            userId: "u2",
            displayName: "Alex",
            avatarToken: nil,
            isOwner: false,
            latestDate: "2026-09-13",
            todayPlanned: 3,
            todayCompleted: 1,
            sevenDayCompleted: 4,
            cheersToday: 0,
            progressUpdatedAt: .now
        )
        let memberRow = TyfeCircleMemberRowView(
            member: member,
            progress: progress,
            focusStatus: .focusing,
            isSelf: false,
            isViewerOwner: true,
            sentKinds: [.heart],
            onCheer: { _ in },
            onRemove: {}
        )

        _ = memberRow
    }

    @Test func textFieldAcceptsInjectedData() {
        let field = TyfeTextFieldView(placeholder: "Family", text: .constant(""))
        let codeField = TyfeTextFieldView(
            placeholder: "Invite code",
            text: .constant("ABCD2345"),
            autocapitalization: .characters
        )

        _ = Group {
            field
            codeField
        }
    }
}
