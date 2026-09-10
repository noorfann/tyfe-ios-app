import SwiftUI
import UIKit
import Testing
@testable import tyfe_ios_app

struct DesignTokensTests {

    @Test func foundationGeometryUsesFourPointRhythm() {
        #expect(TyfeSpacing.unit == 4)
        #expect(TyfeSpacing.control == 16)
        #expect(TyfeSpacing.card == 24)
        #expect(TyfeRadius.control == 16)
        #expect(TyfeRadius.card == 20)
        #expect(TyfeRadius.surface == 28)
        #expect(TyfeStroke.standard == 2)
        #expect(TyfeStroke.emphasis == 3)
    }

    @Test func motionProvidesReducedMotionAlternative() {
        #expect(TyfeMotion.normalDuration > TyfeMotion.reducedDuration)
        #expect(TyfeMotion.reducedDuration == 0)
    }

    @Test func warmCanvasTokensResolveDistinctLightAndDarkValues() {
        #expect(hex(TyfeEditorialPalette.ink, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.ink, for: .dark) == "F7F3EA")
        #expect(hex(TyfeEditorialPalette.canvas, for: .light) == "F7F3EA")
        #expect(hex(TyfeEditorialPalette.canvas, for: .dark) == "201F1A")
        #expect(hex(TyfeEditorialPalette.paper, for: .light) == "FFFDF8")
        #expect(hex(TyfeEditorialPalette.paper, for: .dark) == "2D3440")
    }

    @Test func focusChamberTokensResolveDistinctLightAndDarkValues() {
        #expect(hex(TyfeEditorialPalette.navy, for: .light) == "F7F3EA")
        #expect(hex(TyfeEditorialPalette.navy, for: .dark) == "172338")
        #expect(hex(TyfeEditorialPalette.charcoal, for: .light) == "FFFDF8")
        #expect(hex(TyfeEditorialPalette.charcoal, for: .dark) == "2D3440")
        #expect(hex(TyfeEditorialPalette.onDark, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.onDark, for: .dark) == "FFFDF7")
    }

    @Test func accentFillTextStaysFixedDarkInBothModes() {
        #expect(hex(TyfeEditorialPalette.onAccent, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.onAccent, for: .dark) == "1E201C")
        #expect(hex(TyfeEditorialPalette.onError, for: .light) == "FFFDF7")
        #expect(hex(TyfeEditorialPalette.onError, for: .dark) == "FFFDF7")
    }

    @Test func semanticStatesResolveReadableDarkVariants() {
        #expect(hex(TyfeEditorialPalette.error, for: .light) == "A33E2F")
        #expect(hex(TyfeEditorialPalette.error, for: .dark) == "E5806F")
        #expect(hex(TyfeEditorialPalette.success, for: .dark) == "6FCE92")
        #expect(hex(TyfeEditorialPalette.warning, for: .dark) == "E5B25A")
    }

    private func hex(_ color: Color, for scheme: ColorScheme) -> String {
        let uiColor = UIColor(color)
        let resolved = uiColor.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%02lX%02lX%02lX",
                      lroundf(Float(red) * 255),
                      lroundf(Float(green) * 255),
                      lroundf(Float(blue) * 255))
    }
}
