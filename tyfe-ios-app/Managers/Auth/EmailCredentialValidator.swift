//
//  EmailCredentialValidator.swift
//  tyfe-ios-app
//
//  Shared client-side validation for email + password entry. The server remains
//  the source of truth; this only avoids obvious round-trips.
//

import Foundation

enum EmailCredentialValidator {

    static let minimumPasswordLength = 6

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("@"), !trimmed.hasSuffix(".") else { return false }
        guard !trimmed.contains(where: { $0.isWhitespace }), trimmed.filter({ $0 == "@" }).count == 1 else { return false }
        guard let atIndex = trimmed.firstIndex(of: "@") else { return false }
        let domain = trimmed[trimmed.index(after: atIndex)...]
        guard domain.contains("."), !domain.hasPrefix("."), !domain.contains("..") else { return false }
        guard trimmed[..<atIndex].count >= 1 else { return false }
        return true
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    static func isValidCode(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
