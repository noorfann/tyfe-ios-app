# Manager Templates

Substitute `{ManagerName}` (PascalCase), `{managerName}` (camelCase), and `{RibName}` (PascalCase, defaults to "Core") throughout.

## File 1: {ManagerName}Manager.swift

```swift
import SwiftUI

@MainActor
@Observable
class {ManagerName}Manager {

    private let service: {ManagerName}Service
    private let logManager: LogManager?

    init(service: {ManagerName}Service, logManager: LogManager? = nil) {
        self.logManager = logManager
        self.service = service
    }

}

extension {ManagerName}Manager {

    enum Event: LoggableEvent {

        var eventName: String {
            switch self {
            }
        }

        var parameters: [String: Any]? {
            switch self {
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
```

## File 2: {ManagerName}Service.swift

```swift
import SwiftUI

@MainActor
protocol {ManagerName}Service: Sendable {

}
```

## File 3: Mock{ManagerName}Service.swift

```swift
import SwiftUI

@MainActor
class Mock{ManagerName}Service: {ManagerName}Service {

    init() {

    }

}
```

## File 4: Production Service

**Naming convention:** Name after the SDK/vendor it wraps if specific (e.g., `FirebaseAvatarService`, `RevenueCatPurchaseService`). Use `Prod{ManagerName}Service` only if the implementation is generic and not tied to a specific third-party SDK.

```swift
import SwiftUI

struct Prod{ManagerName}Service: {ManagerName}Service {

}
```

---

## Dependencies.swift Registration Snippet

Add inside `Dependencies.init()` — declare the variable at the top, then initialize in each switch arm:

```swift
// At top of init:
let {managerName}Manager: {ManagerName}Manager

// In .mock arm:
{managerName}Manager = {ManagerName}Manager(service: Mock{ManagerName}Service(), logManager: logManager)

// In .dev, .prod arm:
{managerName}Manager = {ManagerName}Manager(service: Prod{ManagerName}Service(), logManager: logManager)

// After switch, in container registration:
container.register({ManagerName}Manager.self, service: {managerName}Manager)
```

## {RibName}Interactor.swift Resolution Snippet

```swift
// Add private property:
private let {managerName}Manager: {ManagerName}Manager

// In init(container:):
self.{managerName}Manager = container.resolve({ManagerName}Manager.self)!
```
