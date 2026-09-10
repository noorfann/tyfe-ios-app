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
        #expect(copy.contains("progression"))
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
}
