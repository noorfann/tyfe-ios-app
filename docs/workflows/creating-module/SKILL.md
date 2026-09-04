---
name: creating-module
description: Add a new navigation module to the app. Modules are top-level navigation contexts that replace the entire screen hierarchy (e.g., onboarding, tabbar, admin). Use when the user asks to add a new module, create a new app section that replaces the current flow, or add a new top-level navigation context. Modules use router.showModule and require ModuleWrapperView wrapping.
---

# Creating Module

Add a new top-level navigation module to the app. Modules replace the entire screen hierarchy — they are not pushed or presented, they swap the whole view tree.

## Existing Modules

The app ships with two modules:

| Module | ID | Content |
|--------|----|---------|
| Onboarding | `Constants.onboardingModuleId` | `onboardingFlow()` — WelcomeView → sign in/up → OnboardingCompletedView |
| Tabbar | `Constants.tabbarModuleId` | `coreModuleTabBarView()` — TabBarView with Home, Beta, Profile tabs |

## ModuleWrapperView

Every module is wrapped in a `ModuleWrapperView` — a shared component that provides deep link (`.onOpenURL`) and push notification (`.onNotificationReceived`) handling at the module level.

**Files** — `Core/ModuleWrapper/`:

| File | Purpose |
|------|---------|
| `ModuleWrapperView.swift` | View wrapper + `ModuleWrapperDelegate` struct + CoreBuilder extension |
| `ModuleWrapperPresenter.swift` | Handles deep link and push notification routing |
| `ModuleWrapperInteractor.swift` | Protocol extending `GlobalInteractor` |
| `ModuleWrapperRouter.swift` | Protocol extending `GlobalRouter` |

**ModuleWrapperDelegate** carries the `moduleId: String` so deep link/push handlers know which module is active and can route accordingly.

**WARNING**: ModuleWrapperView does NOT have a NavigationStack. The presenter cannot use `router.showScreen(.push)`. It can use `.fullScreenCover`, `.sheet`, `showModal`, `showAlert`, update interactor state, or post a notification. See the `adding-deep-link` skill for details.

The ModuleWrapper already exists in the starter project — you do not need to create it. You only need to wrap your module's content with `moduleWrapperView(router:delegate:)`.

## Steps

1. Get the module name and purpose from the user (camelCase for ID, e.g., `"admin"`, `"settings"`)
2. Add the module ID constant
3. Create the entry view builder method
4. Create the switch method on CoreRouter
5. Add the starting module case in AppView (if applicable)
6. Create the module's root content

## Files to Update

| # | File | What to Add |
|---|------|-------------|
| 1 | `Utilities/Constants.swift` | `static let {moduleName}ModuleId = "{moduleName}"` |
| 2 | `Core/AppView/AppView.swift` | Entry view method, CoreRouter switch method, starting module case (if needed) |

## Step-by-Step

### 1. Add module ID constant

In `Utilities/Constants.swift`:

```swift
static let {moduleName}ModuleId = "{moduleName}"
```

### 2. Create entry view builder method

In `Core/AppView/AppView.swift`, add to the `CoreBuilder` extension:

```swift
func {moduleName}ModuleEntryView(router: AnyRouter, delegate: ModuleWrapperDelegate) -> some View {
    moduleWrapperView(router: router, delegate: delegate) {
        // Module's root content — either inline or a separate builder method
        {moduleName}RootView()
    }
}
```

Every module entry view **must** be wrapped in `moduleWrapperView(router:delegate:)` — this provides deep link and push notification handling.

### 3. Create switch method on CoreRouter

In `Core/AppView/AppView.swift`, add a new `CoreRouter` extension:

```swift
extension CoreRouter {

    func switchTo{ModuleName}Module() {
        let delegate = ModuleWrapperDelegate(moduleId: Constants.{moduleName}ModuleId)
        router.showModule(.trailing, id: delegate.moduleId, onDismiss: nil) { router in
            self.builder.{moduleName}ModuleEntryView(router: router, delegate: delegate)
        }
    }
}
```

### 4. Add starting module case (if applicable)

If the module can be the starting module on app launch, add a case in the `appView()` builder method:

```swift
func appView() -> some View {
    AppView(
        presenter: AppPresenter(interactor: interactor),
        content: {
            switch interactor.startingModuleId {
            case Constants.tabbarModuleId:
                // existing tabbar case
            case Constants.{moduleName}ModuleId:
                let delegate = ModuleWrapperDelegate(moduleId: Constants.{moduleName}ModuleId)
                RouterView(id: delegate.moduleId, addNavigationStack: false, addModuleSupport: true) { router in
                    {moduleName}ModuleEntryView(router: router, delegate: delegate)
                }
            default:
                // existing onboarding case
            }
        }
    )
}
```

Most modules do **not** need to be starting modules — only add this if the app should launch directly into this module under certain conditions.

### 5. Create the module's root content

The module needs root content — typically a new screen or flow. Use the `creating-screen` skill to scaffold the root screen if needed.

For simple modules, the root content can be inline in the entry view method. For complex modules with their own navigation flow, create a builder method (like `onboardingFlow()` or `coreModuleTabBarView()`).

## Switching Between Modules

To switch to the new module from any screen:

1. Add `func switchTo{ModuleName}Module()` to the screen's Router protocol
2. Call `router.switchTo{ModuleName}Module()` from the Presenter
3. CoreRouter already has the implementation from step 3 above

```swift
// In a screen's Router protocol:
@MainActor
protocol SettingsRouter: GlobalRouter {
    func switchTo{ModuleName}Module()
}

// In the Presenter:
func onSwitchModule() {
    router.switchTo{ModuleName}Module()
}
```

## RouterView Configuration

Every module's `RouterView` at the root level uses:

```swift
RouterView(id: delegate.moduleId, addNavigationStack: false, addModuleSupport: true) { router in
    // entry view
}
```

- `id:` — the module ID for identification
- `addNavigationStack: false` — modules manage their own NavigationStack internally (e.g., inside TabBarView or the module's first screen)
- `addModuleSupport: true` — required for `router.showModule()` to work

## Key Patterns

- **All modules wrap in `moduleWrapperView`** — provides deep link and push notification handling via `ModuleWrapperDelegate`
- **Module IDs are constants** — defined in `Constants.swift`, used for `RouterView(id:)` and `router.showModule(id:)`
- **`showModule` replaces everything** — it swaps the entire view hierarchy, not a push or sheet
- **Transition direction** — `.trailing` slides the new module in from the right (most common)
- **Entry view methods live in `AppView.swift`** — in the `CoreBuilder` extension, alongside existing module entry views
- **Switch methods live in `AppView.swift`** — in `CoreRouter` extensions, alongside existing switch methods
- **One file for all module wiring** — `AppView.swift` is the single file for module entry views, switch methods, and starting module logic
- **`startingModuleId` comes from UserDefaults** — `AppState` reads `UserDefaults.lastModuleId` to determine which module to show on launch
