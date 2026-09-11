import Foundation
import Testing
@testable import tyfe_ios_app

struct SupabaseConfigurationTests {

    @Test func acceptsNewPublishableKey() {
        let configuration = SupabaseConfiguration(
            urlString: "https://example.supabase.co",
            publishableKey: "sb_publishable_abc123"
        )
        #expect(configuration?.url.host == "example.supabase.co")
        #expect(configuration?.publishableKey == "sb_publishable_abc123")
    }

    @Test func rejectsSecretKey() {
        #expect(SupabaseConfiguration(
            urlString: "https://example.supabase.co",
            publishableKey: "sb_secret_abc123"
        ) == nil)
    }

    @Test func rejectsPersonalAccessToken() {
        #expect(SupabaseConfiguration(
            urlString: "https://example.supabase.co",
            publishableKey: "sbp_abc123"
        ) == nil)
    }

    @Test func rejectsLegacyServiceRoleJWT() {
        #expect(SupabaseConfiguration(
            urlString: "https://example.supabase.co",
            publishableKey: jwt(role: "service_role")
        ) == nil)
    }

    @Test func acceptsLegacyAnonymousJWT() {
        let key = jwt(role: "anon")
        let configuration = SupabaseConfiguration(
            urlString: "https://example.supabase.co",
            publishableKey: key
        )
        #expect(configuration?.publishableKey == key)
    }

    @Test func rejectsEmptyAndMalformedValues() {
        #expect(SupabaseConfiguration(urlString: "", publishableKey: "sb_publishable_abc") == nil)
        #expect(SupabaseConfiguration(urlString: "not a url", publishableKey: "sb_publishable_abc") == nil)
        #expect(SupabaseConfiguration(urlString: "http://example.supabase.co", publishableKey: "sb_publishable_abc") == nil)
        #expect(SupabaseConfiguration(urlString: "https://example.supabase.co", publishableKey: "") == nil)
    }

    @Test func trimsWhitespace() {
        let configuration = SupabaseConfiguration(
            urlString: "  https://example.supabase.co  ",
            publishableKey: "  sb_publishable_abc123  "
        )
        #expect(configuration?.url.absoluteString == "https://example.supabase.co")
        #expect(configuration?.publishableKey == "sb_publishable_abc123")
    }

    private func jwt(role: String) -> String {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = "{\"role\":\"\(role)\"}"
        return "\(base64URL(header)).\(base64URL(payload)).signature"
    }

    private func base64URL(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
