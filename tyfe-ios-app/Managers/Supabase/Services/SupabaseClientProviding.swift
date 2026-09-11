import Foundation

@MainActor
protocol SupabaseClientProviding: AnyObject {
    var isConfigured: Bool { get }
}
