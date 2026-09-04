//
//  SwiftfulDataManagers+Alias.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 10/18/25.
//
import SwiftfulDataManagers

extension DataLogType {

    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .severe:
            return .severe
        }
    }

}

extension LogManager: @retroactive DataSyncLogger {

    public func trackEvent(event: any DataSyncLogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }

}
