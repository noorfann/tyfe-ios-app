---
name: creating-test
description: Scaffold a unit test file using the Swift Testing framework. Use when the user asks to create tests, add unit tests, write tests for a manager/presenter/interactor, or scaffold a test file. Mirrors the app's folder structure with _Tests naming convention.
---

# Creating Test

Scaffold a unit test file using Swift Testing (`@Test`, `#expect`, `#require`) — not XCTest.

## Steps

1. Identify the class/struct to test (e.g., `UserManager`, `HomePresenter`)
2. Determine the test file location (see below)
3. Read [references/swift-testing-patterns.md](references/swift-testing-patterns.md) for assertion and async patterns
4. Create the test file with the template below
5. Add test methods for the key behaviors

## File Location

Test files **mirror the app's folder structure** inside the unit test target, with a `_Tests` suffix:

| App File | Test File |
|----------|-----------|
| `Managers/User/UserManager.swift` | `tyfe-ios-appUnitTests/Managers/User/UserManager_Tests.swift` |
| `Core/Home/HomePresenter.swift` | `tyfe-ios-appUnitTests/Core/Home/HomePresenter_Tests.swift` |
| `Managers/ABTest/Services/MockABTestService.swift` | Generally not tested (it's already a mock) |

Create intermediate folders as needed to match the app structure.

## Template

```swift
import Testing
@testable import tyfe-ios-app

struct {ClassName}_Tests {

    @Test
    @MainActor
    func someMethodReturnsExpectedResult() async throws {
        // Given
        let sut = {ClassName}(service: Mock{ServiceName}Service(), logManager: nil)

        // When
        let result = await sut.someMethod()

        // Then
        #expect(result == expected)
    }
}
```

## Key Patterns

- **Use Swift Testing** — `@Test` + `#expect` + `#require`, NOT XCTest classes
- **Use structs** for test containers, not classes
- **`@testable import tyfe-ios-app`** — gives access to internal types
- **`@MainActor`** on tests that test `@MainActor` types (managers, presenters) — do NOT use `@MainActor` on non-UI tests
- **Inject mock services** — test the manager/presenter in isolation, never use Prod services
- **Given/When/Then comments** inside each test method — do NOT put these keywords in the method name
- **No `test` prefix needed** — Swift Testing uses `@Test` macro instead
- **Display names** — `@Test("Descriptive name")` for human-readable failure output
- **`#require` for preconditions** — use `try #require(value)` to unwrap optionals and halt early instead of force-unwrapping
- **Parameterize** — use `@Test(arguments:)` instead of copy-pasting test methods that differ only in input
- **Method naming**: descriptive camelCase (e.g., `signOutClearsUser`, `loadDataWithErrorSetsErrorState`)
- **Struct naming**: `_Tests` suffix (e.g., `UserManager_Tests`)

## What to Test

- **Managers**: State changes after method calls, service interactions, error handling, signIn/signOut flows
- **Presenters**: Action methods trigger correct interactor/router calls, state updates
- **Models**: Init, CodingKeys encode/decode, computed properties, mock data validity
- **Do NOT test**: Mock services (they're test infrastructure), pure UI components, private methods
