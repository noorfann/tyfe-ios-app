import Foundation
import Observation

/// Stores only recovery information. Passwords, codes, and session tokens never enter this store.
@Observable
@MainActor
final class EmailRegistrationStore {
    private(set) var pending: PendingEmailRegistration?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults? = nil, key: String = "tyfe.email-registration") {
        self.defaults = defaults
        self.key = key
        if let data = defaults?.data(forKey: key) {
            pending = try? JSONDecoder().decode(PendingEmailRegistration.self, from: data)
        }
    }

    func save(_ registration: PendingEmailRegistration?) throws {
        if let registration {
            let data = try JSONEncoder().encode(registration)
            defaults?.set(data, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }
        pending = registration
    }
}
