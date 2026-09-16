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
        #expect(hex(TyfeEditorialPalette.ink, for: .dark) == "F1F1EF")
        #expect(hex(TyfeEditorialPalette.canvas, for: .light) == "F7F3EA")
        #expect(hex(TyfeEditorialPalette.canvas, for: .dark) == "191919")
        #expect(hex(TyfeEditorialPalette.paper, for: .light) == "FFFDF8")
        #expect(hex(TyfeEditorialPalette.paper, for: .dark) == "202020")
        #expect(hex(TyfeEditorialPalette.muted, for: .light) == "5B6460")
        #expect(hex(TyfeEditorialPalette.muted, for: .dark) == "A9A9A6")
    }

    @Test func focusChamberTokensResolveDistinctLightAndDarkValues() {
        #expect(hex(TyfeEditorialPalette.navy, for: .light) == "F7F3EA")
        #expect(hex(TyfeEditorialPalette.navy, for: .dark) == "191919")
        #expect(hex(TyfeEditorialPalette.charcoal, for: .light) == "FFFDF8")
        #expect(hex(TyfeEditorialPalette.charcoal, for: .dark) == "282828")
        #expect(hex(TyfeEditorialPalette.onDark, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.onDark, for: .dark) == "F1F1EF")
    }

    @Test func darkOutlinesBalanceSoftnessAndControlVisibility() {
        #expect(hex(TyfeEditorialPalette.border, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.border, for: .dark) == "373737")
        #expect(hex(TyfeEditorialPalette.controlBorder, for: .light) == "1E201C")
        #expect(hex(TyfeEditorialPalette.controlBorder, for: .dark) == "6B6B6B")
        #expect(hex(TyfeEditorialPalette.disabledFill, for: .light) == "D8D6CF")
        #expect(hex(TyfeEditorialPalette.disabledFill, for: .dark) == "2C2C2C")
        #expect(hex(TyfeEditorialPalette.disabledInk, for: .light) == "727873")
        #expect(hex(TyfeEditorialPalette.disabledInk, for: .dark) == "787774")
    }

    @Test func darkTextAndControlBoundariesMeetContrastTargets() {
        #expect(contrastRatio(TyfeEditorialPalette.ink, TyfeEditorialPalette.canvas, for: .dark) >= 4.5)
        #expect(contrastRatio(TyfeEditorialPalette.muted, TyfeEditorialPalette.canvas, for: .dark) >= 4.5)
        #expect(contrastRatio(TyfeEditorialPalette.ink, TyfeEditorialPalette.paper, for: .dark) >= 4.5)
        #expect(contrastRatio(TyfeEditorialPalette.muted, TyfeEditorialPalette.charcoal, for: .dark) >= 4.5)
        #expect(contrastRatio(TyfeEditorialPalette.controlBorder, TyfeEditorialPalette.paper, for: .dark) >= 3)
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
        let resolved = resolvedColor(color, for: scheme)
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

    private func contrastRatio(_ foreground: Color, _ background: Color, for scheme: ColorScheme) -> CGFloat {
        let foregroundLuminance = relativeLuminance(resolvedColor(foreground, for: scheme))
        let backgroundLuminance = relativeLuminance(resolvedColor(background, for: scheme))
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func resolvedColor(_ color: Color, for scheme: ColorScheme) -> UIColor {
        UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
        )
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearize(red))
            + (0.7152 * linearize(green))
            + (0.0722 * linearize(blue))
    }
}
