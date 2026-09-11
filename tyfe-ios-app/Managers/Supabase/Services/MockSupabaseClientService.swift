import Foundation

@MainActor
final class MockSupabaseClientService: SupabaseClientProviding {
    var isConfigured: Bool { false }
}
