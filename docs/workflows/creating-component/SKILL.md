---
name: creating-component
description: Scaffold a reusable SwiftUI component in Components/. Use when the user asks to create a new component, reusable view, card, cell, modal, or shared UI element. Components are dumb UI — no business logic, no Presenters, all data and actions injected.
---

# Creating Component

Scaffold a reusable SwiftUI component — pure UI with injected data and actions.

## Steps

1. Get the component name from the user (PascalCase, must end in `View` — e.g., "ProfileCardView", "LoadingSpinnerView", "CustomModalView")
2. Determine the subfolder (see below)
3. Create a single file: `{ComponentName}View.swift`
4. Add multiple `#Preview` blocks for different states

## Folder Location

**Screen-specific components** — used by only one screen — go inside that screen's folder:

```text
Core/{ScreenName}/Components/{ScreenName}HeaderView.swift
```

**Generic/reusable components** — used across multiple screens — go in the shared Components folder:

```text
Components/Views/StretchyHeaderView.swift
Components/Modals/CustomModalView.swift
Components/Images/ImageLoaderView.swift
Components/ViewModifiers/ButtonViewModifiers.swift
```

| Subfolder | Use For |
|-----------|---------|
| `Views/` | General reusable views (DEFAULT) |
| `Modals/` | Modal/popup overlay components |
| `Images/` | Image-related components |
| `ViewModifiers/` | ViewModifier structs |

If unclear, ask the user whether the component is screen-specific or reusable.

## Component Rules

- **No business logic** — pure UI rendering only
- **No `@State` for data** — only `@State private var` for local UI animation state
- **No `@Observable` objects, no Presenters** — components are not VIPER modules
- **All data injected via `var` properties with default values** — not `let`, so the implicit init has defaults
- **Make as much as possible optional** — unwrap in the view body
- **All actions are closures with defaults** — e.g., `var onTap: () -> Void = { }`
- **`import SwiftfulUI`** when using `.asButton()`, `.tappableBackground()`, `.ifSatisfiesCondition()`, or other SwiftfulUI extensions
- Follow the `swiftui-patterns` rules for layout, buttons, images, text

## Template

```swift
import SwiftUI
import SwiftfulUI

struct {ComponentName}View: View {

    var title: String? = nil
    var subtitle: String? = nil
    var onTap: () -> Void = { }

    var body: some View {
        VStack(spacing: 8) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .asButton(.press) {
            onTap()
        }
    }
}

#Preview("Full Data") {
    {ComponentName}View(
        title: "Title",
        subtitle: "Subtitle",
        onTap: { }
    )
}

#Preview("Title Only") {
    {ComponentName}View(
        title: "Title"
    )
}

#Preview("Empty") {
    {ComponentName}View()
}
```

## Previews

- Create **multiple named `#Preview` blocks** — at minimum: full data, partial data, empty/nil state
- Components don't need `RouterView` or builder wiring — just instantiate directly
- For modals, preview inside a `ZStack` with a dark background to simulate the overlay context
