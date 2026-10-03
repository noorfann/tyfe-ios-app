import Testing
@testable import tyfe_ios_app

struct SignupUserModelTests {
    @Test func guestUpgradePreservesOnboardingAndSubmittedProfileFields() {
        let existing = UserModel(
            userId: "guest", creationVersion: "1.0",
            submittedEmail: "person@example.com", submittedName: "Ada",
            submittedProfileImage: "local-avatar", didCompleteOnboarding: true
        )
        let permanent = UserAuthInfo(uid: "guest", email: "person@example.com", authProviders: [.email])
        let updated = UserModel(auth: permanent, creationVersion: nil, existingUser: existing)
        #expect(updated.didCompleteOnboarding == true)
        #expect(updated.submittedName == "Ada")
        #expect(updated.submittedProfileImage == "local-avatar")
        #expect(updated.creationVersion == "1.0")
        #expect(updated.isAnonymous == false)
    }

    @Test func anotherAccountNeverInheritsGuestProfileFields() {
        let guest = UserModel(userId: "guest", submittedName: "Private name", didCompleteOnboarding: true)
        let permanent = UserAuthInfo(uid: "other", email: "person@example.com", authProviders: [.email])
        let updated = UserModel(auth: permanent, creationVersion: nil, existingUser: guest)
        #expect(updated.submittedName == nil)
        #expect(updated.didCompleteOnboarding == nil)
    }
}
