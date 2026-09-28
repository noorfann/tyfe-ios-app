import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct ProjectAppearanceTests {

    @Test func customColorsRoundTripAsUppercaseOpaqueRGB() {
        let selectedColor = Color(hex: "12abcd")
        let token = ProjectColorOption.token(from: selectedColor)

        #expect(token == "#12ABCD")
        #expect(ProjectColorOption.normalizedToken("#12aBcD") == "#12ABCD")
        #expect(ProjectColorOption.title(for: token) == "Custom color #12ABCD")
        #expect(ProjectColorOption.color(for: token).asHex() == "#12ABCD")
        #expect(ProjectColorOption.isCustomToken(token))
    }

    @Test func namedPaletteTokensAndInvalidColorFallbackRemainStable() {
        #expect(ProjectColorOption.normalizedToken("olive") == "olive")
        #expect(ProjectColorOption.title(for: "olive") == "Olive")
        #expect(ProjectColorOption.normalizedToken(nil) == ProjectModel.defaultColorToken)
        #expect(ProjectColorOption.normalizedToken("not-a-color") == ProjectModel.defaultColorToken)
        #expect(ProjectColorOption.title(for: "#12XX56") == "Teal")
        #expect(ProjectColorOption.color(for: "#12XX56").asHex() == ProjectColorOption.teal.color.asHex())
        #expect(!ProjectColorOption.isCustomToken("olive"))
    }
}
