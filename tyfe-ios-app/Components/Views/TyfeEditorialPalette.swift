import SwiftUI

enum TyfeEditorialPalette {

    // Warm Canvas surfaces adapt to the system light/dark appearance.
    static let ink = Color(dynamicLight: "1E201C", dark: "F1F1EF")
    static let canvas = Color(dynamicLight: "F7F3EA", dark: "191919")
    static let paper = Color(dynamicLight: "FFFDF8", dark: "202020")

    // Focus Chamber surfaces. In light mode the chamber uses warm surfaces
    // so the Focus screen follows the system; dark mode joins the soft-black system.
    static let navy = Color(dynamicLight: "F7F3EA", dark: "191919")
    static let charcoal = Color(dynamicLight: "FFFDF8", dark: "282828")
    static let onDark = Color(dynamicLight: "1E201C", dark: "F1F1EF")

    // Dark surfaces use subtle structural borders. Interactive controls keep a
    // stronger boundary so their shape remains distinguishable.
    static let border = Color(dynamicLight: "1E201C", dark: "373737")
    static let controlBorder = Color(dynamicLight: "1E201C", dark: "6B6B6B")

    // Brand accents stay constant so the game-board identity survives both modes.
    static let focus = Color(hex: "D7F36A")
    static let olive = Color(hex: "7A9568")
    static let slateBlue = Color(hex: "96AEC2")
    static let terracotta = Color(hex: "B84F39")
    static let saffron = Color(hex: "DDA13A")
    static let teal = Color(hex: "5FA9A6")

    static let muted = Color(dynamicLight: "5B6460", dark: "A9A9A6")

    // Shadows stay dark in both modes so they read as depth rather than glow.
    static let shadow = Color.black

    // Text and icons that sit on the constant brand accent fills (lime, saffron,
    // teal, terracotta). These accents stay the same in both modes, so their
    // labels stay a fixed dark ink for contrast.
    static let onAccent = Color(hex: "1E201C")

    // Semantic feedback colors keep state legible without making color the only cue.
    static let success = Color(dynamicLight: "2E7D4F", dark: "6FCE92")
    static let warning = Color(dynamicLight: "A66305", dark: "E5B25A")
    static let error = Color(dynamicLight: "A33E2F", dark: "E5806F")
    static let errorFill = Color(hex: "A33E2F")
    static let onError = Color(hex: "FFFDF7")
    static let disabledFill = Color(dynamicLight: "D8D6CF", dark: "2C2C2C")
    static let disabledInk = Color(dynamicLight: "727873", dark: "787774")
    static let onLight = ink

    // Compatibility aliases for the first Editorial Board slice.
    static let sage = olive
    static let lavender = slateBlue
    static let sky = slateBlue
    static let orange = terracotta
    static let amber = saffron
    static let magenta = terracotta
    static let cyan = teal
}
