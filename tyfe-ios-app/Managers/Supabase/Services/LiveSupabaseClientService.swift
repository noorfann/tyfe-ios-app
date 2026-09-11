#if !MOCK && canImport(Supabase)
import Foundation
import Supabase

@MainActor
final class LiveSupabaseClientService: SupabaseClientProviding {
    let client: SupabaseClient

    var isConfigured: Bool { true }

    init(configuration: SupabaseConfiguration) {
        self.client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }
}
#endif
