import SwiftUI

enum TyfeEditorialPalette {
    static let ink = Color(hex: "1E201C")
    static let canvas = Color(hex: "F7F3EA")
    static let paper = Color(hex: "FFFDF8")
    static let navy = Color(hex: "172338")
    static let charcoal = Color(hex: "2D3440")
    static let onDark = Color(hex: "FFFDF7")
    static let focus = Color(hex: "D7F36A")
    static let olive = Color(hex: "7A9568")
    static let slateBlue = Color(hex: "96AEC2")
    static let terracotta = Color(hex: "B84F39")
    static let saffron = Color(hex: "DDA13A")
    static let teal = Color(hex: "5FA9A6")
    static let muted = Color(hex: "5B6460")

    // Semantic feedback colors keep state legible without making color the only cue.
    static let success = Color(hex: "2E7D4F")
    static let warning = Color(hex: "A66305")
    static let error = Color(hex: "A33E2F")
    static let disabledFill = Color(hex: "D8D6CF")
    static let disabledInk = Color(hex: "727873")
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
