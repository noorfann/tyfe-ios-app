import Foundation

@MainActor
protocol FocusClock {
    var now: Date { get }
}

@MainActor
struct SystemFocusClock: FocusClock {
    var now: Date { Date() }
}
