import SwiftUI

enum ProjectColorOption: String, CaseIterable, Identifiable {
    case focus
    case olive
    case slateBlue
    case terracotta
    case saffron
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Lime"
        case .olive: return "Olive"
        case .slateBlue: return "Slate blue"
        case .terracotta: return "Terracotta"
        case .saffron: return "Saffron"
        case .teal: return "Teal"
        }
    }

    var color: Color {
        switch self {
        case .focus: return TyfeEditorialPalette.focus
        case .olive: return TyfeEditorialPalette.olive
        case .slateBlue: return TyfeEditorialPalette.slateBlue
        case .terracotta: return TyfeEditorialPalette.terracotta
        case .saffron: return TyfeEditorialPalette.saffron
        case .teal: return TyfeEditorialPalette.teal
        }
    }

    static func color(for token: String?) -> Color {
        guard let token else { return Self.teal.color }
        if let option = Self(rawValue: token) { return option.color }
        guard let hex = customHex(from: token) else { return Self.teal.color }
        return Color(hex: hex)
    }

    static func title(for token: String?) -> String {
        guard let token else { return Self.teal.title }
        if let option = Self(rawValue: token) { return option.title }
        guard let hex = customHex(from: token) else { return Self.teal.title }
        return "Custom color #\(hex)"
    }

    static func normalizedToken(_ token: String?) -> String {
        guard let token else { return ProjectModel.defaultColorToken }
        if let option = Self(rawValue: token) { return option.rawValue }
        guard let hex = customHex(from: token) else { return ProjectModel.defaultColorToken }
        return "#\(hex)"
    }

    static func token(from color: Color) -> String {
        color.asHex().uppercased()
    }

    static func isCustomToken(_ token: String?) -> Bool {
        guard let token else { return false }
        return customHex(from: token) != nil
    }

    private static func customHex(from token: String) -> String? {
        guard token.count == 7, token.first == "#" else { return nil }
        let hex = String(token.dropFirst())
        guard UInt32(hex, radix: 16) != nil else { return nil }
        return hex.uppercased()
    }
}
