import Foundation

enum ProgressionAwardSource: String, Codable, CaseIterable, Hashable {
    case focusSession
    case bonusSession
}

struct ProgressionMilestoneModel: Identifiable, Codable, Hashable {
    let milestoneId: String
    let requiredXP: Int
    let title: String
    let cosmeticId: String
    let isUnlocked: Bool

    var id: String {
        milestoneId
    }

    static func fixture(requiredXP: Int, isUnlocked: Bool) -> Self {
        Self(
            milestoneId: "milestone-\(requiredXP)",
            requiredXP: requiredXP,
            title: "Level the board",
            cosmeticId: "cosmetic-\(requiredXP)",
            isUnlocked: isUnlocked
        )
    }
}

struct ProgressionSnapshotModel: Codable, Hashable {
    let totalXP: Int
    let level: Int
    let currentLevelXP: Int
    let xpToNextLevel: Int
    let nextMilestone: ProgressionMilestoneModel?
    let unlockedCosmeticIds: [String]

    init(
        totalXP: Int,
        nextMilestone: ProgressionMilestoneModel? = nil,
        unlockedCosmeticIds: [String]? = nil
    ) {
        let safeXP = max(totalXP, 0)
        let currentLevelXP = safeXP % 100
        self.totalXP = safeXP
        self.level = (safeXP / 100) + 1
        self.currentLevelXP = currentLevelXP
        self.xpToNextLevel = 100 - currentLevelXP
        self.nextMilestone = nextMilestone ?? Self.nextMilestone(for: safeXP)
        self.unlockedCosmeticIds = unlockedCosmeticIds ?? Self.cosmetics(for: safeXP)
    }

    var eventParameters: [String: Any] {
        [
            "progression_total_xp": totalXP,
            "progression_level": level,
            "progression_current_level_xp": currentLevelXP,
            "progression_xp_to_next_level": xpToNextLevel,
            "progression_unlocked_cosmetic_count": unlockedCosmeticIds.count
        ]
    }

    static var mock: Self {
        Self(totalXP: 40)
    }

    static var noXPMock: Self {
        Self(totalXP: 0)
    }

    static var levelUpMock: Self {
        Self(totalXP: 100)
    }

    static var cosmeticUnlockedMock: Self {
        Self(totalXP: 200)
    }

    private static func nextMilestone(for totalXP: Int) -> ProgressionMilestoneModel {
        let nextXP = ((totalXP / 200) + 1) * 200
        return .fixture(requiredXP: nextXP, isUnlocked: false)
    }

    private static func cosmetics(for totalXP: Int) -> [String] {
        guard totalXP >= 200 else { return [] }
        return stride(from: 200, through: totalXP, by: 200).map { "cosmetic-\($0)" }
    }
}

struct ProgressionAwardModel: Identifiable, Codable, Hashable {
    let awardId: String
    let focusSessionId: String
    let source: ProgressionAwardSource
    let points: Int
    let awardedAt: Date
    let idempotencyKey: String

    var id: String {
        awardId
    }

    init(
        awardId: String,
        focusSessionId: String,
        source: ProgressionAwardSource,
        awardedAt: Date,
        idempotencyKey: String
    ) {
        self.awardId = awardId
        self.focusSessionId = focusSessionId
        self.source = source
        self.points = 10
        self.awardedAt = awardedAt
        self.idempotencyKey = idempotencyKey
    }

    static var mock: Self {
        Self(
            awardId: "progression-award-focus",
            focusSessionId: FocusSessionModel.completedMock.focusSessionId,
            source: .focusSession,
            awardedAt: Date(timeIntervalSince1970: 1_756_944_000),
            idempotencyKey: "focus-session-completed-xp"
        )
    }

    static var bonusMock: Self {
        Self(
            awardId: "progression-award-bonus",
            focusSessionId: "focus-session-bonus",
            source: .bonusSession,
            awardedAt: Date(timeIntervalSince1970: 1_756_944_000),
            idempotencyKey: "focus-session-bonus-xp"
        )
    }
}
