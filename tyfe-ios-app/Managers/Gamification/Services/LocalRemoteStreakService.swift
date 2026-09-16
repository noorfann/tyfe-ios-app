import Foundation
import SwiftfulGamification

@MainActor
final class LocalRemoteStreakService: RemoteStreakService {
    private typealias StreakContinuation = AsyncThrowingStream<CurrentStreakData, Error>.Continuation

    static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("streak-store-v1.json")
    }

    private let fileURL: URL
    private var snapshot: Snapshot
    private var continuations: [ContinuationKey: [UUID: StreakContinuation]] = [:]

    init(fileURL: URL = LocalRemoteStreakService.defaultFileURL) {
        self.fileURL = fileURL
        self.snapshot = Self.loadSnapshot(from: fileURL)
    }

    func streamCurrentStreak(
        userId: String,
        streakKey: String
    ) -> AsyncThrowingStream<CurrentStreakData, Error> {
        let continuationId = UUID()
        let key = ContinuationKey(userId: userId, streakKey: streakKey)
        let currentStreak = record(userId: userId, streakKey: streakKey).currentStreak
        let (stream, continuation) = AsyncThrowingStream<CurrentStreakData, Error>.makeStream()

        var keyContinuations = continuations[key] ?? [:]
        keyContinuations[continuationId] = continuation
        continuations[key] = keyContinuations

        if let currentStreak {
            continuation.yield(currentStreak)
        }

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.removeContinuation(id: continuationId, key: key)
            }
        }

        return stream
    }

    func updateCurrentStreak(
        userId: String,
        streakKey: String,
        streak: CurrentStreakData
    ) async throws {
        try updateRecord(userId: userId, streakKey: streakKey) { record in
            record.currentStreak = streak
        }
        emit(streak, userId: userId, streakKey: streakKey)
    }

    // swiftlint:disable:next function_parameter_count
    func calculateStreak(
        userId: String,
        streakKey: String,
        eventsRequiredPerDay: Int,
        leewayHours: Int,
        freezeBehavior: FreezeBehavior,
        timezone: String?
    ) async throws { }

    func addEvent(userId: String, streakKey: String, event: StreakEvent) async throws {
        try updateRecord(userId: userId, streakKey: streakKey) { record in
            guard !record.events.contains(where: { $0.id == event.id }) else { return }
            record.events.append(event)
        }
    }

    func getAllEvents(userId: String, streakKey: String) async throws -> [StreakEvent] {
        record(userId: userId, streakKey: streakKey).events
    }

    func deleteAllEvents(userId: String, streakKey: String) async throws {
        try updateRecord(userId: userId, streakKey: streakKey) { record in
            record.events = []
        }
    }

    func addStreakFreeze(userId: String, streakKey: String, freeze: StreakFreeze) async throws {
        try updateRecord(userId: userId, streakKey: streakKey) { record in
            guard !record.freezes.contains(where: { $0.id == freeze.id }) else { return }
            record.freezes.append(freeze)
        }
    }

    func useStreakFreeze(userId: String, streakKey: String, freezeId: String) async throws {
        try updateRecord(userId: userId, streakKey: streakKey) { record in
            guard let index = record.freezes.firstIndex(where: { $0.id == freezeId }) else {
                throw ServiceError.freezeNotFound
            }
            let freeze = record.freezes[index]
            record.freezes[index] = StreakFreeze(
                id: freeze.id,
                dateEarned: freeze.dateEarned,
                dateUsed: Date(),
                dateExpires: freeze.dateExpires
            )
        }
    }

    func getAllStreakFreezes(userId: String, streakKey: String) async throws -> [StreakFreeze] {
        record(userId: userId, streakKey: streakKey).freezes
    }

    private func record(userId: String, streakKey: String) -> Record {
        snapshot.users[userId]?[streakKey] ?? Record()
    }

    private func updateRecord(
        userId: String,
        streakKey: String,
        update: (inout Record) throws -> Void
    ) throws {
        var nextSnapshot = snapshot
        var userStreaks = nextSnapshot.users[userId] ?? [:]
        var nextRecord = userStreaks[streakKey] ?? Record()
        try update(&nextRecord)
        userStreaks[streakKey] = nextRecord
        nextSnapshot.users[userId] = userStreaks
        try save(nextSnapshot)
        snapshot = nextSnapshot
    }

    private func save(_ snapshot: Snapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func loadSnapshot(from fileURL: URL) -> Snapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot()
        }
        return snapshot
    }

    private func emit(_ streak: CurrentStreakData, userId: String, streakKey: String) {
        let key = ContinuationKey(userId: userId, streakKey: streakKey)
        continuations[key]?.values.forEach { $0.yield(streak) }
    }

    private func removeContinuation(id: UUID, key: ContinuationKey) {
        continuations[key]?[id] = nil
        if continuations[key]?.isEmpty == true {
            continuations[key] = nil
        }
    }
}

private extension LocalRemoteStreakService {
    struct ContinuationKey: Hashable {
        let userId: String
        let streakKey: String
    }

    struct Snapshot: Codable {
        var users: [String: [String: Record]] = [:]
    }

    struct Record: Codable {
        var currentStreak: CurrentStreakData?
        var events: [StreakEvent] = []
        var freezes: [StreakFreeze] = []
    }

    enum ServiceError: LocalizedError {
        case freezeNotFound

        var errorDescription: String? {
            switch self {
            case .freezeNotFound: return "The streak freeze could not be found."
            }
        }
    }
}
