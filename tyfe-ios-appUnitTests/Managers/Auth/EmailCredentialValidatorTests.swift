import Foundation
import Testing
@testable import tyfe_ios_app

struct EmailCredentialValidatorTests {

    @Test func acceptsSimpleEmail() {
        #expect(EmailCredentialValidator.isValidEmail("person@example.com"))
    }

    @Test func acceptsEmailWithSurroundingWhitespace() {
        #expect(EmailCredentialValidator.isValidEmail("  person@example.com  "))
    }

    @Test(arguments: ["", "person", "person@", "@example.com", "person@example", "person@.", "person@@example.com", "per son@example.com", "person@.com", "person@example..com"])
    func rejectsMalformedEmail(_ email: String) {
        #expect(!EmailCredentialValidator.isValidEmail(email))
    }

    @Test func acceptsPasswordAtMinimumLength() {
        #expect(EmailCredentialValidator.isValidPassword("abcdef"))
    }

    @Test func rejectsPasswordBelowMinimumLength() {
        #expect(!EmailCredentialValidator.isValidPassword("abcde"))
        #expect(EmailCredentialValidator.minimumPasswordLength == 6)
    }

    @Test(arguments: ["123456", "000001"])
    func acceptsSixDigitCode(_ code: String) {
        #expect(EmailCredentialValidator.isValidCode(code))
    }

    @Test(arguments: ["", "12345", "1234567", "12a456", "１２３４５６"])
    func rejectsInvalidCode(_ code: String) {
        #expect(!EmailCredentialValidator.isValidCode(code))
    }
}
