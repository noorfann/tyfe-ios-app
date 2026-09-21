//
//  NotificationCenter.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 1/11/25.
//
import NotificationCenter

// We can use NotificationCenter to send notifications within the codebase.
// These are usually "anti-pattern" and "anti-architecture"
// But are an easy solution for scenarios where two parts of the codebase are not otherwise connected
//
// 1. Create a custom Notification.Name
// 2. Trigger notification with .post()
// 3. Receive notification with .onNotificationReceived() (must be connected before notification triggers)

extension Notification.Name {
    
    /// Notification for when app is opened from a Push Notification
    static let pushNotification = Notification.Name("PushNotification")

    /// Notification for opening the active Focus Session from its Live Activity
    static let focusLiveActivityNavigation = Notification.Name("FocusLiveActivityNavigation")
}
