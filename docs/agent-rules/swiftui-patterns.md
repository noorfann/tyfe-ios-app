# SwiftUI Patterns & Modern APIs

Rules for building SwiftUI views and components in this project.

## UI Conventions

### Buttons
- ALWAYS use `.asButton()` instead of wrapping in `Button()` — never use `Button()` directly
- `.asButton(.press)` — scale feedback, default for most interactive elements
- `.asButton(.tap)` — no visual feedback, replaces `onTapGesture`
- `.asButton(.highlight)` — accent overlay, rarely used
- `.asButton(.opacity)` — dimming effect, rarely used
- `.callToActionButton()` and `.badgeButton()` are convenience modifiers — use them or build custom button UI directly, whichever is easier
- `.tappableBackground()` before `.asButton()` if the view has transparent areas
- Image-only buttons must always include an accessible text label

### Images
- ALWAYS use `ImageLoaderView(urlString:)` for URL images — never `AsyncImage`
- `ImageLoaderView` handles resizing internally — just apply `.frame()` and optionally `.clipShape()`

### Layout
- NEVER use `Spacer()` — use `frame(maxWidth: .infinity)` or `frame(maxHeight: .infinity)` with alignment instead. `Spacer()` is almost never needed and makes layouts harder to control. Examples:
  - Push content to one side: `.frame(maxWidth: .infinity, alignment: .leading)` instead of `HStack { Text("Hello"); Spacer() }`
  - Push content to top: `.frame(maxHeight: .infinity, alignment: .top)` instead of `VStack { Text("Hello"); Spacer() }`
  - Center with remaining space: `.frame(maxWidth: .infinity)` (centered by default)
- Use spacing parameters in stacks: `VStack(spacing: 12)` instead of extra padding
- Standard spacing values: 4, 8, 12, 16, 24
- `.ignoresSafeArea()` on full-bleed background images only
- Use `overlay`/`background` for decorating a primary view (child adopts parent's size) — use `ZStack` for composing peer views that jointly define layout

### Text
- Dynamic Type fonts: `.largeTitle`, `.title3`, `.headline`, `.body`, `.subheadline`, `.caption`
- `.font(.system(size:))` rarely — common for system icon sizing (exact, not resizable for accessibility) but not for body text
- `.lineLimit(1).minimumScaleFactor(0.3)` to prevent truncation on single-line text
- `.foregroundStyle(.secondary)` for de-emphasized text — not `.opacity()`
- Use `localizedStandardContains()` instead of `contains()` for user-input search filtering — handles diacritics and case

### Lists
- `.removeListRowFormatting()` available to strip default list row styling — use when the design calls for custom row backgrounds
- `ForEach` must use stable identifiers — never `.indices` for dynamic content

### Common Containers
- `LazyVStack` / `LazyHStack` — use inside `ScrollView` for large or dynamic content (loads views on demand)
- `VStack` / `HStack` — use for small, fixed-size layouts where all items should load immediately
- `List` — use for settings-style screens with sections, swipe actions, and built-in styling
- `GeometryReader` — use sparingly, mainly when you need the parent's exact size. Prefer `containerRelativeFrame()`, `visualEffect()`, or `onGeometryChange(for:)` (iOS 17+) when possible
- `.contentTransition(.numericText())` — animate text value changes (counters, timers). Also supports `.interpolate` for general text morphing and `.symbolEffect` for SF Symbol animations

## View Composition

- For sections only used within one screen, use computed properties or `@ViewBuilder` functions — keeps the code local and simple
- Extract into a separate `struct` only when the section is a reusable component used across multiple screens
- Generic components use `@ViewBuilder let content: Content` for flexible injection
- Keep `body` pure — no side effects, no object creation, no heavy computation
- Use `.opacity()` or `.overlay()` for state changes on the same view — use `if/else` or `.ifSatisfiesCondition()` only for fundamentally different views

## Animation

- Prefer transforms for animations (`scaleEffect`, `offset`, `rotationEffect`) — these are GPU-accelerated. Avoid animating `frame` or `padding` (triggers layout recalculation)
- Transitions require animation context OUTSIDE the conditional — place `withAnimation` or `.animation()` on the parent, not inside the `if` block
- `.phaseAnimator` (iOS 17+) for multi-step animation sequences — replaces `DispatchQueue.asyncAfter` chains
- Guard before assigning state in `onChange`/`onReceive` — check `if newValue != oldValue` to avoid redundant view updates
- In scroll handlers and hot paths, only update state when crossing a threshold — not on every pixel

## Property Wrappers

| Wrapper | Use When |
|---------|----------|
| `@State var` | Holding the Presenter, or owning an `@Observable` class |
| `@State private var` | Local UI animation state only |
| `@Binding var` | Child needs to modify parent's state (rare in VIPER — prefer injecting a value + closure instead) |
| `@Bindable var` | Injected `@Observable` needing `$` bindings (rarely needed in VIPER) |
| `let` / `var` | `let` is ok but prefer `var` and optional for injected data — allows customizing the implicit init with defaults. NEVER write `= nil` on optional vars — it is redundant and triggers SwiftLint warnings. Write `var title: String?` not `var title: String? = nil` |


## Previews

- Create multiple named `#Preview` blocks for different states
- Use `DevPreview.shared.container()` for the default mock container
- To customize preview state, re-register specific services on the container to override defaults
- **Components MUST also include a `#Preview("Variety")` block** showing multiple instances in a `ScrollView` + `VStack` (for list-style components) or `ScrollView` + `HStack`/`LazyVGrid` (for grid/card components). This makes it easy to see how the component looks across different data combinations and in context.
- Use `Constants.randomImage` as the image URL in previews
- Wrap in `RouterView` when the view needs routing context

```swift
#Preview("Default") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.screenView(router: router, delegate: ScreenDelegate())
    }
}

#Preview("Premium User") {
    let container = DevPreview.shared.container()
    container.register(PurchaseManager.self, service: PurchaseManager(service: MockPurchaseService(activeEntitlements: [.mock])))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.screenView(router: router, delegate: ScreenDelegate())
    }
}

#Preview("Signed Out") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: nil)))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.screenView(router: router, delegate: ScreenDelegate())
    }
}
```

Common overrides:
- Auth state: `container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: .mock(isAnonymous: true))))`
- Premium: `container.register(PurchaseManager.self, service: PurchaseManager(service: MockPurchaseService(activeEntitlements: [.mock])))`
- AB tests: `container.register(ABTestManager.self, service: ABTestManager(service: MockABTestService(someTest: true)))`
- Slow/error states: `container.register(SomeService.self, service: MockSomeService(delay: 20, showError: true))`

### Screen vs Modal Previews

**Screens** (push, sheet, fullScreenCover) — use `RouterView` + builder as normal.

**Custom modals** (overlay components via `router.showModal`) — trigger via the CoreRouter method so it displays exactly as it will in the app:
```swift
#Preview("Modal") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)

    return RouterView { router in
        let router = CoreRouter(router: router, builder: builder)

        return Text("Show modal")
            .onFirstAppear {
                router.showProfileModal(avatar: .mock, onXMarkPressed: { })
            }
    }
}
```

### Alerts

Use `router.showAlert()` from GlobalRouter — never native `.alert()` modifier.

- `router.showSimpleAlert(title:subtitle:)` — basic alert with OK button
- `router.showAlert(error:)` — display an error message
- `router.showAlert(.alert, title:subtitle:buttons:)` — alert with custom buttons
- `router.showAlert(.confirmationDialog, title:subtitle:buttons:)` — action sheet style
- `router.dismissAlert()` — dismiss programmatically

## Lifecycle Modifiers

- `.onAppear { }` for synchronous work on every appearance
- `.task { }` for async work (auto-cancelled on disappear)
- `.task(id: value)` for value-dependent async tasks
- `.onFirstAppear { }` for one-time synchronous setup (from SwiftfulUI)
- `.onFirstTask { }` for one-time async setup (from SwiftfulUI)
- `.screenAppearAnalytics(name:)` on every screen view

## ScrollView (Modern APIs — iOS 17+)

- `.scrollIndicators(.hidden)` — hide scroll bars (not `showsIndicators: false`)
- `.scrollPosition(id: $selection)` — track/control visible item via binding (preferred over `ScrollViewReader`)
- `.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)` — snap-to-item scrolling
- `.scrollTargetLayout()` + `.scrollTargetBehavior(.paging)` — full-page paging (use with `.containerRelativeFrame(.horizontal)` on each item)
- `.scrollTransition(.interactive)` — animate items as they enter/leave the viewport (scale, opacity, etc.)
- `.containerRelativeFrame(.horizontal)` — size items relative to the scroll container
- `.scrollClipDisabled()` — allow content to visually overflow the scroll bounds
- `.contentMargins()` — add margins to scroll content without affecting the scroll indicator

## Deprecated API Replacements

IMPORTANT: Never use deprecated APIs. Always use the modern replacement.

| Deprecated | Use Instead |
|------------|-------------|
| `foregroundColor()` | `foregroundStyle()` |
| `NavigationView` / `NavigationStack` | SwiftfulRouting (`RouterView`, `router.showScreen()`) |
| `ObservableObject` + `@StateObject` | `@Observable` + `@State` |
| `@EnvironmentObject` | `@Environment(MyType.self)` with `@Observable` |
| `onChange(of:) { value in }` | `onChange(of:) { old, new in }` or `onChange(of:) { }` |
| `ScrollView(showsIndicators: false)` | `.scrollIndicators(.hidden)` |
| `String(format:)` for display | `Text(value, format: .number)` |
| `fontWeight(.bold)` | `bold()` |
| `.animation(.spring)` (no value) | `.animation(.spring, value: flag)` |
| `AnyView(...)` | `@ViewBuilder` functions |
| `.font(.system(size: 24))` for body text | `.font(.title)` (Dynamic Type) |
| `DispatchQueue.asyncAfter` chains | `.phaseAnimator` (iOS 17+) |
