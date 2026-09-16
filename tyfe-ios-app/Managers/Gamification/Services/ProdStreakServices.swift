import Foundation
import SwiftfulGamification

@MainActor
struct ProdStreakServices: StreakServices {
    let remote: RemoteStreakService
    let local: LocalStreakPersistence

    init(fileURL: URL = LocalRemoteStreakService.defaultFileURL) {
        self.remote = LocalRemoteStreakService(fileURL: fileURL)
        self.local = FileManagerStreakPersistence()
    }
}
