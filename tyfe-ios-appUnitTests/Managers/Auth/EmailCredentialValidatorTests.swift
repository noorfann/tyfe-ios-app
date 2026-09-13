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

    @Test(arguments: ["", "person", "person@", "@example.com", "person@example", "person@."])
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
}
