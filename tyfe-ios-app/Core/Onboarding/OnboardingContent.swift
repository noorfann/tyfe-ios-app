import SwiftUI

enum OnboardingArtKind {
    case hero
    case focus
    case circles
}

struct OnboardingPage: Identifiable, Equatable {
    let id: String
    let eyebrow: String
    let title: String
    let body: String
    let symbolName: String
    let accent: Color
    let art: OnboardingArtKind
    let pills: [String]?

    init(
        id: String,
        eyebrow: String,
        title: String,
        body: String,
        symbolName: String,
        accent: Color,
        art: OnboardingArtKind,
        pills: [String]? = nil
    ) {
        self.id = id
        self.eyebrow = eyebrow
        self.title = title
        self.body = body
        self.symbolName = symbolName
        self.accent = accent
        self.art = art
        self.pills = pills
    }
}

enum OnboardingContent {

    static let continueButtonTitle = "Continue"
    static let primaryButtonTitle = "Pick your first Activity"
    static let skipButtonTitle = "Skip for now"
    static let skipAccessibilityLabel = "Skip onboarding for now"

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "loop",
            eyebrow: "WELCOME TO TYFE",
            title: "Focus a little.\nRest a lot.",
            body: "Make a simple plan, focus on one thing, then enjoy your break.",
            symbolName: "sparkles",
            accent: TyfeEditorialPalette.teal,
            art: .hero
        ),
        OnboardingPage(
            id: "focus",
            eyebrow: "FOCUS & REWARDS",
            title: "25 minutes of focus\ngets you real downtime.",
            body: "Finish a 25-minute Focus Session to earn 1 Reward Credit. Use your credits for 15, 30, or 60 minutes of downtime.",
            symbolName: "timer",
            accent: TyfeEditorialPalette.focus,
            art: .focus,
            pills: ["1 credit per session", "15, 30, or 60 min", "Credits never expire"]
        ),
        OnboardingPage(
            id: "everything",
            eyebrow: "WHAT'S INCLUDED",
            title: "Everything you need\nto keep going.",
            body: "Make a Daily Plan, earn Rewards, and cheer each other on in private Circles. Tyfe works offline, too.",
            symbolName: "person.2.fill",
            accent: TyfeEditorialPalette.slateBlue,
            art: .circles,
            pills: ["Daily Plan", "Rewards", "Private Circles", "Works offline"]
        )
    ]
}
