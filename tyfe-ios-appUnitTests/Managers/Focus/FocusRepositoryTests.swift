import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct FocusRepositoryTests {

    @Test func localPersistenceRoundTripsSnapshot() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tyfe-focus-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = LocalFocusRepositoryPersistence(fileURL: fileURL)
        let snapshot = FocusManagerSnapshot.homeFlowMock

        try persistence.save(snapshot)

        #expect(try persistence.load() == snapshot)
    }
}
