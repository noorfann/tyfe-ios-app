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

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "loop",
            eyebrow: "TYFE",
            title: "Turn effort into\ndeliberate downtime.",
            body: "Plan a little, focus fully, then rest without the guilt.",
            symbolName: "sparkles",
            accent: TyfeEditorialPalette.teal,
            art: .hero
        ),
        OnboardingPage(
            id: "focus",
            eyebrow: "FOCUS & REWARDS",
            title: "25 focused minutes\nearn real rest.",
            body: "Finish a 25-minute Focus Session to earn 1 Reward Credit, then trade credits for bounded downtime.",
            symbolName: "timer",
            accent: TyfeEditorialPalette.focus,
            art: .focus,
            pills: ["1 credit per session", "15 · 30 · 60 min downtime", "Credits never expire"]
        ),
        OnboardingPage(
            id: "everything",
            eyebrow: "EVERYTHING YOU GET",
            title: "A private loop\nthat is yours alone.",
            body: "A forgiving Daily Plan, bounded Rewards, and private Circles with Cheers — all working offline.",
            symbolName: "person.2.fill",
            accent: TyfeEditorialPalette.slateBlue,
            art: .circles,
            pills: ["Daily Plan", "Bounded Rewards", "Private Circles", "Works offline"]
        )
    ]
}
