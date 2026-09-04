# AB Test Wiring Checklist

When adding a new AB test, update these files in order. Substitute `{testName}` (camelCase), `{TestName}` (PascalCase), and `{YYYYMM}` (date prefix, e.g., `202411`).

---

## Bool Test

### 1. ActiveABTests.swift

```swift
// Add property:
private(set) var {testName}: Bool

// Add to init:
{testName}: Bool

// Add CodingKey:
case {testName} = "_{YYYYMM}_{TestName}"

// Add to eventParameters:
"test\(CodingKeys.{testName}.rawValue)": {testName}

// Add mutating method:
mutating func update({testName} newValue: Bool) {
    {testName} = newValue
}

// Add to init(config: RemoteConfig):
let {testName} = config.configValue(forKey: ActiveABTests.CodingKeys.{testName}.rawValue).boolValue
self.{testName} = {testName}

// Add to asNSObjectDictionary:
CodingKeys.{testName}.rawValue: {testName} as NSObject
```

### 2. All ABTestService implementations in `Managers/ABTests/Services/`

List all files in the Services folder and update **every** one. Read each file to understand its pattern, then add the new test following the existing convention. Common patterns:

**Mock services** (e.g., `MockABTestService`):
```swift
// Add optional init parameter:
{testName}: Bool? = nil

// Add to ActiveABTests init:
{testName}: {testName} ?? false
```

**Local/UserDefault services** (e.g., `LocalABTestService`):
```swift
// Add @UserDefault property:
@UserDefault(key: ActiveABTests.CodingKeys.{testName}.rawValue, startingValue: .random())
private var {testName}: Bool

// Add to activeTests computed property:
{testName}: {testName}

// Add to saveUpdatedConfig:
{testName} = updatedTests.{testName}
```

**Remote services** (e.g., Firebase, Mixpanel, etc.):
```swift
// Add to default values in init():
{testName}: false
```

### 3. DevSettingsPresenter.swift

```swift
// Add property:
var {testName}: Bool = false

// Add to loadABTests():
{testName} = interactor.activeTests.{testName}

// Add handler:
func handle{TestName}Change(oldValue: Bool, newValue: Bool) {
    updateTest(
        property: &{testName},
        newValue: newValue,
        savedValue: interactor.activeTests.{testName},
        updateAction: { tests in
            tests.update({testName}: newValue)
        }
    )
}
```

### 4. DevSettingsView.swift

```swift
// Add to abTestSection:
Toggle("{TestName}", isOn: $presenter.{testName})
    .onChange(of: presenter.{testName}, presenter.handle{TestName}Change)
```

### 5. CoreInteractor.swift

```swift
// Add computed property in ABTestManager section:
var {testName}: Bool {
    abTestManager.activeTests.{testName}
}
```

---

## Enum Test

If the test has more than 2 options, create an enum instead of using Bool.

### 0. Create {TestName}Option.swift

Create in `Managers/ABTests/Models/`:

```swift
import SwiftUI

enum {TestName}Option: String, Codable, CaseIterable {
    case optionA, optionB

    static var `default`: Self {
        .optionA
    }
}
```

### 1-5. Same as Bool Test

Follow the same 5-step checklist above, substituting:
- `Bool` → `{TestName}Option`
- `false` → `.default`
- `Toggle(...)` → `Picker(...)` with `ForEach({TestName}Option.allCases)`
- `.random()` → `{TestName}Option.allCases.randomElement()!` in LocalABTestService
- `@UserDefault` → `@UserDefaultEnum` in LocalABTestService
- `config.configValue(...).boolValue` → parse string to enum in RemoteConfig init

DevSettingsView picker:

```swift
Picker("{TestName}", selection: $presenter.{testName}) {
    ForEach({TestName}Option.allCases, id: \.self) { option in
        Text(option.rawValue)
            .id(option)
    }
}
.onChange(of: presenter.{testName}, presenter.handle{TestName}Change)
```
