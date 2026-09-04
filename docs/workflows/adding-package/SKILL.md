---
name: adding-package
description: Add a Swift package dependency to the project and wire it in. Use when the user asks to add a package, library, SDK, or third-party dependency. Covers Xcode SPM setup, Alias file creation, logger conformance, and when to use the creating-manager skill for service implementations.
---

# Adding Package

Add a Swift Package Manager dependency and wire it into the project.

## Steps

1. Determine the package name, repository URL, and version requirement
2. Instruct the user to add the SPM dependency in Xcode (manual step)
3. Determine the integration type (see below)
4. Create the Alias file
5. If the package provides a service, use the `creating-manager` skill to scaffold the manager

## Adding SPM Dependency (Manual)

SPM dependencies are added via Xcode — this cannot be done from the CLI for `.xcodeproj` projects.

Instruct the user:
1. In Xcode: File → Add Package Dependencies
2. Enter the repository URL
3. Set the version rule (usually "Up to Next Major Version")
4. Select the library products to add to the app target

## Integration Types

| Type | When | Alias File | Manager |
|------|------|------------|---------|
| **Service package** | Package provides a service conforming to a manager's protocol (e.g., `RevenueCatPurchaseService`) | Yes | Yes — use `creating-manager` skill |
| **Manager package** | Package provides a complete manager (e.g., `HapticManager`, `LogManager`) | Yes | Register directly in Dependencies.swift |
| **Utility package** | Package provides helpers, extensions, UI components (e.g., `SwiftfulUI`, `SDWebImageSwiftUI`) | Optional | No |

### Service Package

The package provides a service implementation that plugs into a manager's service protocol. This is the most common pattern.

Example: `SwiftfulPurchasingRevenueCat` provides `RevenueCatPurchaseService` conforming to `PurchaseService`.

1. Create the Alias file
2. Use the `creating-manager` skill to scaffold the manager, using the package's service as the production service implementation

### Manager Package

The package provides a complete manager class. No custom service protocol needed.

Example: `SwiftfulHaptics` provides `HapticManager` directly.

1. Create the Alias file (with typealiases + logger conformance)
2. Add manager initialization to `Dependencies.swift` (mock + dev/prod)
3. Register in `DependencyContainer`
4. Resolve in `{RibName}Interactor`
5. Expose methods in the interactor

### Utility Package

The package provides extensions, views, or helpers used directly via `import`.

Example: `SwiftfulUI` provides view modifiers, `SDWebImageSwiftUI` provides `WebImage`.

1. Add `import PackageName` where needed
2. Optionally create an Alias file if the package has types used frequently

## Alias File

Create in the manager's folder: `Managers/{ManagerName}/Swiftful{PackageName}+Alias.swift`

For utility packages without a manager: `Utilities/Swiftful{PackageName}+Alias.swift`

### Template

```swift
import Swiftful{PackageName}

typealias {TypeName} = Swiftful{PackageName}.{TypeName}
typealias Mock{TypeName}Service = Swiftful{PackageName}.Mock{TypeName}Service
```

### Logger Conformance

If the package exposes a logger protocol, add the conformance in the Alias file:

```swift
extension {PackageName}LogType {

    var type: LogType {
        switch self {
        case .info:
            return .info
        case .analytic:
            return .analytic
        case .warning:
            return .warning
        case .severe:
            return .severe
        }
    }

}
extension LogManager: @retroactive {PackageName}Logger {

    public func trackEvent(event: any {PackageName}LogEvent) {
        trackEvent(eventName: event.eventName, parameters: event.parameters, type: event.type.type)
    }

}
```

Not all packages have a logger protocol — check the package's public API first.

## Key Patterns

- **Xcode adds the SPM dependency** — cannot be done from CLI for `.xcodeproj` projects
- **Alias files avoid direct package imports** — code references typealiased names, making package swaps easy
- **Logger conformance is `@retroactive`** — because `LogManager` and the logger protocol are from different modules
- **One Alias file per package** — group all typealiases and conformances in a single file
- **Service packages pair with `creating-manager`** — use the existing skill for the full manager scaffold
- **Check existing Alias files** in `Managers/` for reference on naming and structure
