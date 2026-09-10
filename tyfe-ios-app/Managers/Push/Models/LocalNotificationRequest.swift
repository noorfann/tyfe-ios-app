import Foundation

struct LocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let deliveryDate: Date
}
