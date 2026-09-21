import Testing
@testable import tyfe_ios_app

struct OnboardingContentTests {

    @Test func idsAreUniqueWithLoopFirstAndEverythingLast() {
        let pages = OnboardingContent.pages
        let ids = pages.map(\.id)

        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "loop")
        #expect(ids.last == "everything")
        #expect(pages.count == 3)
    }

    @Test func pagesCoverEveryMvpFeature() {
        let copy = OnboardingContent.pages
            .map { [$0.eyebrow, $0.title, $0.body].joined(separator: " ") }
            .joined(separator: " ")
            .lowercased()

        #expect(copy.contains("25"))
        #expect(copy.contains("reward credit"))
        #expect(copy.contains("circle"))
        #expect(copy.contains("offline"))
        #expect(copy.contains("cheer"))
        #expect(copy.contains("daily plan"))
    }

    @Test func eachPageHasReadableCopy() {
        for page in OnboardingContent.pages {
            #expect(!page.eyebrow.isEmpty)
            #expect(!page.title.isEmpty)
            #expect(!page.body.isEmpty)
            #expect(!page.symbolName.isEmpty)
        }
    }

    @Test func usesSimpleFriendlyCopyAndKeepsOnboardingTerms() {
        let pages = OnboardingContent.pages
        let copy = pages
            .map { [$0.eyebrow, $0.title, $0.body, $0.pills?.joined(separator: " ") ?? ""].joined(separator: " ") }
            .joined(separator: " ")
            .lowercased()

        #expect(pages[0].eyebrow == "WELCOME TO TYFE")
        #expect(pages[0].title == "Focus a little.\nRest a lot.")
        #expect(pages[0].body == "Make a simple plan, focus on one thing, then enjoy your break.")
        #expect(pages[1].title == "25 minutes of focus\ngets you real downtime.")
        #expect(pages[1].pills == ["1 credit per session", "1 credit = 10 min"])
        #expect(pages[2].eyebrow == "WHAT'S INCLUDED")
        #expect(pages[2].title == "Everything you need\nto keep going.")
        #expect(pages[2].pills == ["Daily Plan", "Rewards", "Private Circles", "Works offline"])

        #expect(copy.contains("focus session"))
        #expect(copy.contains("reward credit"))
        #expect(copy.contains("daily plan"))
        #expect(copy.contains("circles"))
        #expect(copy.contains("cheer"))
        #expect(copy.contains("offline"))
    }

    @Test func exposesFriendlyNavigationCopy() {
        #expect(OnboardingContent.continueButtonTitle == "Continue")
        #expect(OnboardingContent.primaryButtonTitle == "Pick your first Activity")
        #expect(OnboardingContent.skipButtonTitle == "Skip for now")
        #expect(OnboardingContent.skipAccessibilityLabel == "Skip onboarding for now")
    }
}
