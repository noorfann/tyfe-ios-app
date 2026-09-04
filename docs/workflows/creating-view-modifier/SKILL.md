---
name: creating-view-modifier
description: Scaffold a custom SwiftUI ViewModifier in Components/ViewModifiers/. Use when the user asks to create a view modifier, add a reusable modifier, create a custom modifier, or build a View extension that wraps behavior. ViewModifiers encapsulate reusable view transformations (appearance, behavior, layout) and always include a View extension for ergonomic usage.
---

# Creating View Modifier

Scaffold a ViewModifier struct with a View extension in `Components/ViewModifiers/`.

## Steps

1. Get the modifier name and purpose from the user
2. Determine the file name (see naming below)
3. Create the ViewModifier struct
4. Add a View extension method
5. Add `#Preview` blocks demonstrating usage

## File Location

All view modifiers go in `Components/ViewModifiers/`:

```
Components/ViewModifiers/{Name}ViewModifier.swift
```

If a file contains multiple related modifiers (e.g., button styles), name it by the group:

```
Components/ViewModifiers/ButtonViewModifiers.swift
```

## Template — Single Modifier

```swift
import SwiftUI

struct {Name}ViewModifier: ViewModifier {

    // Parameters — use defaults where possible
    let title: String
    var isEnabled: Bool = true

    func body(content: Content) -> some View {
        content
            // Apply transformations to content
    }
}

extension View {

    func {modifierName}(title: String, isEnabled: Bool = true) -> some View {
        modifier({Name}ViewModifier(title: title, isEnabled: isEnabled))
    }
}

#Preview {
    Text("Hello, world!")
        .padding()
        .{modifierName}(title: "Example")
}
```

## Template — Modifier with State

For modifiers that track internal state (e.g., first appear, animation):

```swift
import SwiftUI

struct {Name}ViewModifier: ViewModifier {

    @State private var didAppear: Bool = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didAppear else { return }
                didAppear = true
                action()
            }
    }
}

extension View {

    func {modifierName}(action: @escaping () -> Void) -> some View {
        modifier({Name}ViewModifier(action: action))
    }
}
```

## Template — ButtonStyle (Related Pattern)

Custom button styles are not `ViewModifier` but follow the same file location and grouping:

```swift
import SwiftUI

struct {Name}ButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}

extension View {

    func {styleName}Button(action: @escaping () -> Void) -> some View {
        Button(action: action) { self }
            .buttonStyle({Name}ButtonStyle())
    }
}
```

Group related button styles in a single file (e.g., `ButtonViewModifiers.swift`).

## Key Patterns

- **No `@Environment` or Manager references** — ViewModifiers are pure UI transformations. They should never read from `@Environment` or reference any Manager layer. If a modifier needs data, inject it as a parameter
- **Always include a View extension** — callers use `.modifierName()`, never `.modifier(SomeModifier())` directly
- **View extension method names use camelCase** — e.g., `onFirstAppear`, `screenAppearAnalytics`, `onNotificationReceived`
- **Parameters with sensible defaults** — use `var` with defaults in the struct, mirror defaults in the extension
- **`@State` for internal tracking only** — modifiers can have internal state (e.g., `didAppear`) but never expose it
- **Closure parameters use `@escaping`** — and `@MainActor` if they update UI state
- **Multiple modifiers per file is OK** — when they're closely related (e.g., `OnFirstAppearViewModifier` + `OnFirstTaskViewModifier`)
- **`import SwiftfulUI`** — when using `.asButton()`, `.tappableBackground()`, or other SwiftfulUI extensions inside the modifier
- **Previews show the modifier applied** — not the modifier struct itself
