---
name: creating-ab-test
description: Add a new AB test by wiring it through ActiveABTests, all ABTestService implementations, DevSettingsPresenter, DevSettingsView, and CoreInteractor. Use when the user asks to add an AB test, feature flag, remote config test, or experiment. Supports both Bool and enum-based tests.
---

# Creating AB Test

Wire a new AB test through all required files. This is a multi-file mechanical change — every test follows the same pattern across 5+ files.

## Steps

1. Get the test name from the user (camelCase, e.g., `showBanner`, `paywallVariant`)
2. Determine the test type — Bool (on/off) or enum (multiple variants)
3. If enum, create the option enum file first
4. Read [references/checklist.md](references/checklist.md) for the exact code to add in each file
5. Update all files in order

## Test Type

| Type | When | Example |
|------|------|---------|
| **Bool** | Simple on/off flag | `showBanner: Bool` |
| **Enum** | Multiple variants | `paywallVariant: PaywallTestOption` |

For enum tests, create a `{TestName}Option.swift` file in `Managers/ABTests/Models/` with `String, Codable, CaseIterable` conformance and a `static var default`.

## Files to Update (in order)

| # | File | What to Add |
|---|------|-------------|
| 1 | `Managers/ABTests/Models/ActiveABTests.swift` | Property, init param, CodingKey, eventParameters, update method, RemoteConfig init, asNSObjectDictionary |
| 2 | **All files in `Managers/ABTests/Services/`** | Each service conforming to `ABTestService` must be updated to handle the new test property (see below) |
| 3 | `Core/DevSettings/DevSettingsPresenter.swift` | State property, loadABTests line, change handler |
| 4 | `Core/DevSettings/DevSettingsView.swift` | Toggle (Bool) or Picker (enum) in abTestSection |
| 5 | `Root/RIBs/Core/CoreInteractor.swift` | Computed property exposing the test value |

### Updating Service Files

List all files in `Managers/ABTests/Services/` and update **every** one. The specific services may vary by project (e.g., `MockABTestService`, `LocalABTestService`, `FirebaseABTestService`, `MixpanelABTestService`, etc.). For each service, read the file and add the new test property following its existing pattern — mock services get an optional init param, local services get a `@UserDefault`, prod services get a default value.

## Key Patterns

- **CodingKey format**: `"_{YYYYMM}_{TestName}"` — date-prefixed for easy cleanup of old tests
- **ABTestManager does NOT change** — it works generically with `ActiveABTests`
- **DevSettingsView** is the dev-only screen where engineers can override test values locally
- **CoreInteractor** exposes individual test values as computed properties so screen interactor protocols can pick what they need
- **Service implementations vary** — list all files in `Managers/ABTests/Services/` and update each one following its existing pattern
- **Mock services** have optional init parameters with sensible defaults — allows UI tests to configure specific test states
- **Local/UserDefault services** use `@UserDefault` (Bool) or `@UserDefaultEnum` (enum) for persistence
- **Remote services** (Firebase, Mixpanel, etc.) need default values and config parsing

## After Wiring

To use the test in a screen:
1. Add `var {testName}: Bool { get }` (or enum type) to the screen's Interactor protocol
2. CoreInteractor already conforms since the computed property was added in step 5
3. Access via `interactor.{testName}` in the Presenter
4. Use conditionally in the View or Presenter logic
