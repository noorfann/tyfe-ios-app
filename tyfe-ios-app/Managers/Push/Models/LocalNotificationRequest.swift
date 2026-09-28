import Foundation

struct LocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let deliveryDate: Date
    let soundFileName: String?

    init(identifier: String, title: String, body: String, deliveryDate: Date, soundFileName: String? = nil) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.deliveryDate = deliveryDate
        self.soundFileName = soundFileName
    }
}
