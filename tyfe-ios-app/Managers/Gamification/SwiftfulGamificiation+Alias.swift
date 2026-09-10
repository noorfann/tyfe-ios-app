//
//  SwiftfulGamificiation+Alias.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 10/4/25.
//
import SwiftfulGamification

typealias GamificationDictionaryValue = SwiftfulGamification.GamificationDictionaryValue

// Streaks
typealias StreakManager = SwiftfulGamification.StreakManager
typealias MockStreakServices = SwiftfulGamification.MockStreakServices
typealias StreakConfiguration = SwiftfulGamification.StreakConfiguration
typealias StreakEvent = SwiftfulGamification.StreakEvent
typealias CurrentStreakData = SwiftfulGamification.CurrentStreakData
typealias StreakFreeze = SwiftfulGamification.StreakFreeze

typealias ProdStreakServices = SwiftfulGamification.MockStreakServices

// Experience Points

typealias ExperiencePointsManager = SwiftfulGamification.ExperiencePointsManager
typealias MockExperiencePointsServices = SwiftfulGamification.MockExperiencePointsServices
typealias ExperiencePointsConfiguration = SwiftfulGamification.ExperiencePointsConfiguration
typealias CurrentExperiencePointsData = SwiftfulGamification.CurrentExperiencePointsData
typealias ExperiencePointsEvent = SwiftfulGamification.ExperiencePointsEvent

typealias ProdExperiencePointsServices = SwiftfulGamification.MockExperiencePointsServices

// Progress

typealias ProgressManager = SwiftfulGamification.ProgressManager
typealias ProgressConfiguration = SwiftfulGamification.ProgressConfiguration
typealias MockProgressServices = SwiftfulGamification.MockProgressServices
typealias ProgressItem = SwiftfulGamification.ProgressItem

typealias ProdProgressServices = SwiftfulGamification.MockProgressServices

extension GamificationLogType {
    
    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }
    
}
extension LogManager: @retroactive GamificationLogger {
    
    public func trackEvent(event: any GamificationLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }
    
}
