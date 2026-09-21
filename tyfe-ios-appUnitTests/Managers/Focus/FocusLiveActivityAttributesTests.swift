#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusLiveActivityAttributesTests {
    @Test func contentStateUsesDefaultCodableWireShapeBelowActivityKitLimit() throws {
        let state = FocusLiveActivityAttributes.ContentState(
            phase: .running,
            startedAt: Date(timeIntervalSince1970: 1_757_000_000),
            endsAt: Date(timeIntervalSince1970: 1_757_001_500)
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(
            FocusLiveActivityAttributes.ContentState.self,
            from: data
        )

        #expect(decoded == state)
        #expect(data.count < 4_096)
    }
}
#endif
