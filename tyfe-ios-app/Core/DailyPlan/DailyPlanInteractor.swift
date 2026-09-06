import SwiftUI

@MainActor
protocol DailyPlanInteractor: GlobalInteractor {
    @discardableResult
    func acceptPhase1DailyPlan(
        intendedSessionCount: Int,
        activityIds: [String],
        timeBlocks: [PlanTimeBlockModel]?
    ) -> DailyPlanModel
}

extension CoreInteractor: DailyPlanInteractor { }
