# Project Structure

This is a starter template designed to be copied for new iOS app projects. The existing screens are examples showing how to apply the architecture — replace them with your own.

## File Creation

This project uses Xcode file system synchronization. Any `.swift` file created inside `tyfe-ios-app/` is automatically added to Xcode and included in the build. No manual Xcode intervention needed.

## Folder Layout

```
tyfe-ios-app/
├── Root/                          # App entry point and infrastructure
│   ├── tyfe-ios-appApp.swift
│   ├── AppDelegate.swift          # Firebase config, push notifications
│   ├── Dependencies/              # DependencyContainer, Dependencies, DevPreview
│   ├── RIBs/
│   │   ├── Core/                  # CoreRouter, CoreInteractor, CoreBuilder
│   │   └── Global/                # Base protocols (GlobalRouter, GlobalInteractor, Builder)
│   └── EntryPoints/               # Alternative entry points for unit/UI testing
│
├── Core/                          # All screens (VIPER modules)
│   ├── {ScreenName}/              # One folder per screen
│   │   ├── {ScreenName}View.swift
│   │   ├── {ScreenName}Presenter.swift
│   │   ├── {ScreenName}Interactor.swift
│   │   └── {ScreenName}Router.swift
│   ├── AppView/                   # Root navigation coordinator (keep)
│   ├── TabBar/                    # Tab navigation (keep)
│   └── DevSettings/               # Dev-only settings (keep)
│
├── Managers/                      # All managers
│   └── {ManagerName}/             # One folder per manager
│       ├── {ManagerName}Manager.swift
│       ├── Models/                # Manager-specific models
│       └── Services/              # Protocol + Mock/Prod implementations
│
├── Components/                    # Reusable UI
│   ├── Views/                     # Custom view components
│   ├── Modals/                    # Modal UI patterns
│   ├── Images/                    # Image utilities
│   ├── ViewModifiers/             # Custom SwiftUI modifiers
│   └── PropertyWrappers/          # Custom property wrappers
│
├── Extensions/                    # Swift type extensions
│   └── {TypeName}+EXT.swift       # Naming convention
│
├── Utilities/                     # Shared utilities
│   ├── Constants.swift            # App constants, module IDs
│   └── Keys.swift                 # API keys
│
├── SupportingFiles/               # Xcode project resources
│   ├── Assets.xcassets/           # App icons, colors, images
│   │   ├── AppIcon.appiconset/   # App icon
│   │   └── AccentColor.colorset/ # Accent color
│   ├── GoogleServicePLists/       # Firebase configs (Dev + Prod)
│   ├── Preview Content/           # Preview-only assets
│   └── tyfe-ios-app.entitlements  # App capabilities
│
├── tyfe-ios-app.xcodeproj  # Xcode project file
├── tyfe-ios-appUnitTests/  # Unit tests — mirror app folder structure
│   ├── Managers/User/UserManager_Tests.swift
│   ├── Core/Home/HomePresenter_Tests.swift
│   └── ...                           # Match app path + _Tests suffix
├── tyfe-ios-appUITests/    # UI tests (launch tests, flow tests)
├── .swiftlint.yml                    # SwiftLint config
└── rename_project.sh                 # Script to rename project from template
```

## Current Managers

Before creating a new manager, check if the functionality belongs in an existing one.

| Manager | Responsibility |
|---------|---------------|
| AuthManager | Sign in, sign out, reauthenticate, delete account |
| UserManager | User profile data, Firestore sync |
| LogManager | Analytics and logging (Firebase, Mixpanel, Crashlytics) |
| AppState | Global app state, current module |
| PurchaseManager | In-app purchases, entitlements (RevenueCat) |
| ABTestManager | A/B test values (Firebase Remote Config or local) |
| PushManager | Push notification registration and handling |
| HapticManager | Haptic feedback |
| SoundEffectManager | Sound effect playback |
| StreakManager | Daily streak tracking |
| ExperiencePointsManager | XP accumulation |
| ProgressManager | Goal-based progress tracking |

Only create a new manager if the functionality does not fit any existing manager's responsibility.

## Adding a New Screen

Create a folder in `Core/` with 4 files:
- `{Name}View.swift`
- `{Name}Presenter.swift`
- `{Name}Interactor.swift` (protocol)
- `{Name}Router.swift` (protocol)

Then extend `CoreInteractor`, `CoreRouter`, and `CoreBuilder` — see `viper-architecture.md`.

## Adding a New Manager

Create a folder in `Managers/` with:
- `{Name}Manager.swift`
- `Services/` subfolder with protocol + Mock/Prod implementations
- `Models/` subfolder if needed

Then register in `Dependencies.swift` and resolve in `CoreInteractor` — see `manager-lifecycle.md`.

## Build Configurations

| Scheme | Flag | Firebase | Use Case |
|--------|------|----------|----------|
| Mock | `MOCK` | No | Fast dev, previews, UI tests |
| Development | `DEV` | Dev credentials | Integration testing |
| Production | (default) | Prod credentials | Release |

Use Mock for most development. Conditional compilation:
```swift
#if MOCK
// No Firebase
#elseif DEV
// Dev Firebase
#else
// Prod Firebase
#endif
```

## Building and Previews

- Keep verification proportional to the change. Use Xcode diagnostics or previews for focused UI checks, and run a full build or test suite after multi-file changes, new dependencies, configuration changes, or before handoff.
- Prefer the repository's existing Xcode schemes and scripts. Record the exact scheme, destination, and command when verification is important to acceptance.
- Avoid an expensive simulator or archive workflow for a single-file edit unless the user asks for that proof or the change affects runtime behavior that cannot be checked otherwise.

## Module Navigation

Two main modules managed by `AppView`:
- `Constants.onboardingModuleId` — pre-auth flows
- `Constants.tabbarModuleId` — post-auth main app

Switch modules via `router.showModule(moduleId)`.

## Naming Conventions

- Screen folders: PascalCase matching the screen name (`Home/`, `CreateAccount/`)
- Manager folders: PascalCase matching the domain (`Auth/`, `Purchases/`, `User/`)
- Extensions: `{TypeName}+EXT.swift` (`Array+EXT.swift`, `String+EXT.swift`)
- Components: descriptive PascalCase (`CustomModalView.swift`, `ImageLoaderView.swift`)
