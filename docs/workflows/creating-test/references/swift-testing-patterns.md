# Swift Testing Patterns

Reference for writing tests using the modern Swift Testing framework. Based on [AvdLee's Swift Testing Expert Skill](https://github.com/AvdLee/Swift-Testing-Agent-Skill), adapted for this project.

---

## Table of Contents

- [Test Structure](#test-structure)
- [Expectations (#expect)](#expectations-expect)
- [Prerequisites (#require)](#prerequisites-require)
- [Parameterized Testing](#parameterized-testing)
- [Traits and Tags](#traits-and-tags)
- [Known Issues](#known-issues)
- [Testing @MainActor Code](#testing-mainactor-code)
- [Testing with Mock Services](#testing-with-mock-services)
- [Async Testing and Waiting](#async-testing-and-waiting)
- [Testing Cancellation](#testing-cancellation)
- [Testing Memory Management](#testing-memory-management)
- [Serial Execution](#serial-execution-flaky-test-fix)
- [Parallelization and Isolation](#parallelization-and-isolation)
- [Performance Best Practices](#performance-best-practices)
- [XCTest Migration Reference](#xctest-migration-reference)

---

## Test Structure

- Import `Testing` only in test targets — never in app targets.
- Use `@Test` to declare tests. No `test` prefix needed.
- Prefer `struct` suites for value semantics and accidental-state-sharing prevention.
- Use `@Suite` when adding suite-level traits or display names.
- Use display names for human-readable failure output.

```swift
import Testing
@testable import tyfe-ios-app

@Suite("UserManager Tests")
struct UserManager_Tests {

    @Test("Loading user populates currentUser")
    @MainActor
    func loadUserPopulatesCurrentUser() async throws {
        // Given
        let sut = UserManager(service: MockUserService(), logManager: nil)

        // When
        await sut.loadUser(userId: "abc")

        // Then
        #expect(sut.currentUser != nil)
    }
}
```

### Nested Suites

Group related tests by feature behavior:

```swift
struct UserManager_Tests {
    struct SignIn {
        @Test("Sign in sets current user")
        @MainActor
        func signInSetsCurrentUser() async { ... }
    }

    struct SignOut {
        @Test("Sign out clears user")
        @MainActor
        func signOutClearsUser() async { ... }
    }
}
```

### Suite Init

If a suite has instance test methods, it must have a callable zero-argument initializer:

```swift
struct SessionTests {
    let config: URLSessionConfiguration

    init(config: URLSessionConfiguration = .ephemeral) {
        self.config = config
    }

    @Test func usesEphemeral() {
        #expect(config == .ephemeral)
    }
}
```

---

## Expectations (#expect)

`#expect` is the default assertion. Use natural Swift expressions — the framework captures sub-expression values for rich diagnostics.

| Pattern | Example |
|---------|---------|
| Equality | `#expect(a == b)` |
| Truthiness | `#expect(value)` |
| Falsy | `#expect(!value)` |
| Empty check | `#expect(array.isEmpty)` |
| Count check | `#expect(array.count == 3)` |
| Contains | `#expect([10, 20].contains(total))` |
| Error thrown (type) | `#expect(throws: SomeError.self) { try work() }` |
| Error thrown (value) | `#expect(throws: SomeError.missingBeans) { try work() }` |
| No error thrown | `#expect(throws: Never.self) { try work() }` |
| Force fail | `Issue.record("Unreachable")` |

---

## Prerequisites (#require)

Use `try #require(...)` when subsequent lines depend on a prerequisite value. Think of it as "guard + fail test early."

```swift
@Test func parsedURLHasHTTPS() throws {
    let value = "https://www.example.com"
    let url = try #require(URL(string: value), "URL should parse")
    #expect(url.scheme == "https")
}
```

Use `#require` to safely unwrap optionals instead of force-unwrapping or noisy optional chaining:

```swift
@Test
@MainActor
func currentUserHasName() async throws {
    let manager = UserManager(service: MockUserService(), logManager: nil)
    await manager.loadUser(userId: "abc")

    let user = try #require(manager.currentUser, "User should be loaded")
    #expect(!user.name.isEmpty)
}
```

**Rule of thumb:** `#expect` for assertions, `#require` when failure should halt the test.

---

## Parameterized Testing

Replace repetitive copy-paste tests with `@Test(arguments:)`. Each argument becomes its own independent test case with separate diagnostics.

### Single argument

```swift
@Test("Valid entitlements grant premium access", arguments: EntitlementOption.allCases)
func entitlementGrantsAccess(_ entitlement: EntitlementOption) {
    #expect(entitlement.isPremium || entitlement == .free)
}
```

### Multiple arguments (cartesian product)

Two collections generate all combinations:

```swift
enum Region { case us, eu }
enum Plan { case free, pro }

@Test(arguments: [Region.us, .eu], [Plan.free, .pro])
func accessRules(region: Region, plan: Plan) {
    let allowed = canUseFeature(region: region, plan: plan)
    #expect(allowed == (region == .eu && plan == .pro))
}
```

### Paired arguments (zip)

Use `zip` when input A must pair with a corresponding input B:

```swift
@Test("Free trial limits per tier", arguments: zip(
    [Tier.basic, .premium],
    [3, 10]
))
func freeTrialLimits(_ tier: Tier, expected: Int) {
    #expect(freeTries(for: tier) == expected)
}
```

### When to parameterize

- Multiple tests share identical logic, differing only in input values
- You have `for` loops inside tests (worse diagnostics — use `@Test(arguments:)` instead)
- You're copy-pasting test methods changing only one variable

---

## Traits and Tags

### Common Traits

```swift
@Test("Uploads complete quickly", .timeLimit(.seconds(10)))
func uploadWithinTimeLimit() async throws { ... }

@Test(.disabled("Flaky on CI — investigating"), .bug("https://jira.example.com/ISSUE-123"))
func temporaryDisabledTest() { ... }

@Test(.enabled(if: ProcessInfo.processInfo.environment["CI"] == "true"))
func ciOnlySmokeTest() { ... }
```

### Tags

Declare custom tags for cross-suite grouping:

```swift
extension Tag {
    @Tag static var networking: Self
    @Tag static var regression: Self
}

@Suite(.tags(.networking))
struct APITests {
    @Test func fetchUser() async throws { ... }
}

struct CheckoutTests {
    @Test(.tags(.regression))
    func orderTotal() { ... }
}
```

- Tags on suites cascade to all contained tests.
- Use tags for test-plan include/exclude filtering.
- Every `.disabled` test should have a reason and ideally a `.bug` link.

### Availability

Use `@available` on test functions — never on suite types:

```swift
@available(iOS 18, *)
@Test func newPushFormat() { ... }
```

---

## Known Issues

Use `withKnownIssue` for temporary expected failures you still want to compile and run. Better than `.disabled` because the rest of the test still executes.

```swift
@Test func checkoutFlow() {
    #expect(cartIsValid) // still validated

    withKnownIssue("Backend intermittently returns 503", isIntermittent: true) {
        let result = try processPayment()
        #expect(result.success)
    }

    #expect(cartIsCleared) // rest of test still executes
}
```

Remove `withKnownIssue` once the failure is fixed.

---

## Testing @MainActor Code

Most managers and presenters are `@MainActor` — mark the test accordingly. Only use `@MainActor` when the code under test requires it.

```swift
@Test("Loading data populates items")
@MainActor
func loadDataPopulatesItems() async {
    // Given
    let manager = SomeManager(service: MockSomeService(), logManager: nil)

    // When
    await manager.loadData()

    // Then
    #expect(!manager.items.isEmpty)
}
```

---

## Testing with Mock Services

Inject mock services to isolate the unit under test. Never use Prod services in tests.

```swift
@Test("Error service sets error state")
@MainActor
func loadDataWithErrorSetsError() async {
    // Given
    let mockService = MockSomeService(shouldThrow: true)
    let manager = SomeManager(service: mockService, logManager: nil)

    // When
    await manager.loadData()

    // Then
    #expect(manager.items.isEmpty)
    #expect(manager.error != nil)
}
```

---

## Async Testing and Waiting

### Direct await (preferred)

```swift
@Test func fetchNameReturnsValue() async throws {
    let client = APIClient()
    let value = try await client.fetchName()
    #expect(value == "Antoine")
}
```

### Confirmations (event counting)

Use `confirmation` when validating event delivery or count semantics:

```swift
@Test func eventPublishedTwice() async {
    await confirmation("Publishes two events", expectedCount: 2) { confirm in
        confirm()
        confirm()
    }
}
```

### Observing @Observable changes

```swift
@Test
@MainActor
func searchTriggersUpdate() async {
    let manager = SearchManager(service: MockSearchService())

    await confirmation { confirm in
        _ = withObservationTracking {
            manager.results
        } onChange: {
            confirm()
        }

        await manager.search("swift")
    }

    #expect(!manager.results.isEmpty)
}
```

### Callback bridging (completion handlers)

For APIs without async overloads, bridge with continuations:

```swift
@Test func legacyAPI() async throws {
    let value = try await withCheckedThrowingContinuation { continuation in
        legacyLoad { result in
            continuation.resume(with: result)
        }
    }
    #expect(value == 42)
}
```

### Anti-patterns to avoid

- Do NOT use `Task.sleep` as synchronization — use awaitable conditions instead.
- Do NOT return from test before async callback work completes.

---

## Testing Cancellation

```swift
@Test func taskCancellation() async {
    let task = Task {
        try await longRunningOperation()
    }

    task.cancel()

    #expect(throws: CancellationError.self) {
        try await task.value
    }
}
```

---

## Testing Memory Management

```swift
@Test func noRetainCycles() async {
    weak var weakRef: SomeManager?

    do {
        let manager = SomeManager(service: MockSomeService())
        weakRef = manager
        await manager.startTask()
    }

    #expect(weakRef == nil, "Retain cycle detected")
}
```

---

## Serial Execution (Flaky Test Fix)

Use `.serialized` on suites when tests must run one-at-a-time. Treat as a **transitional** measure — fix shared state before normalizing serialization.

For deterministic ordering with `withMainSerialExecutor` from [swift-concurrency-extras](https://github.com/pointfreeco/swift-concurrency-extras):

```swift
import ConcurrencyExtras

@Suite(.serialized)
@MainActor
final class SomeManagerTests {

    @Test
    func isLoadingState() async throws {
        try await withMainSerialExecutor {
            let manager = SomeManager(service: MockSomeService())

            let task = Task { await manager.loadData() }
            await Task.yield()

            #expect(manager.isLoading == true)

            await task.value
            #expect(manager.isLoading == false)
        }
    }
}
```

---

## Parallelization and Isolation

Swift Testing runs tests in **parallel by default** with **randomized order** to expose hidden dependencies.

### Common flakiness source

```swift
// BAD: shared mutable state causes flaky tests
enum SharedStore {
    static var counter = 0
}

@Test func incrementsCounter() {
    SharedStore.counter += 1
    #expect(SharedStore.counter >= 1) // Flaky in parallel
}
```

### Fix: isolate per test

```swift
// GOOD: fresh state per test
@Test func isolatedCounter() {
    var store = CounterStore()
    store.increment()
    #expect(store.counter == 1)
}
```

### Flakiness checklist

- No reliance on execution order
- No shared mutable globals/singletons without reset
- No arbitrary sleeps as synchronization
- No hidden external dependencies in unit tests
- Deterministic fixtures and stable data sources

---

## Performance Best Practices

- Keep tests synchronous where possible — faster and easier to reason about.
- Use `@MainActor` only when code under test requires main-thread isolation.
- Use in-memory fakes for the fast path — reserve real integrations for dedicated test plans.
- Keep setup cheap and scoped — build expensive fixtures only when needed.
- Use parameterized tests to reduce duplicated setup code.
- Prefer determinism over timing-sensitive tests.

---

## XCTest Migration Reference

| XCTest | Swift Testing |
|--------|---------------|
| `class Tests: XCTestCase` | `struct Tests` with `@Test` |
| `func testName()` | `func name()` with `@Test` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNil(error)` | `#expect(error == nil)` |
| `XCTAssertThrowsError(try run())` | `#expect(throws: (any Error).self) { try run() }` |
| `try XCTUnwrap(user)` | `let user = try #require(user)` |
| `XCTFail("...")` | `Issue.record("...")` |
| `continueAfterFailure = false` | Use `#require` for early-stop |
| `expectation(description:)` | `confirmation { confirm in }` |
| `await fulfillment(of:)` | `await confirmation { }` |

Keep XCTest for: UI automation (`XCUIApplication`), performance metrics (`XCTMetric`), Objective-C-only tests.
