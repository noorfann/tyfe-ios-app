---
name: creating-screen
description: Scaffold a new VIPER screen module for the iOS app. Creates 4 files (View, Presenter, Interactor, Router) with Builder, Router, Interactor extensions for the correct RIB. Use when the user asks to create a new screen, add a new page, build a new view, or scaffold a new module.
---

# Creating Screen

Scaffold a complete VIPER screen module. Every screen follows the same 4-file pattern with RIBs wiring.

## Steps

1. Get the screen name from the user (PascalCase, e.g., "Settings", "CreateAccount", "UserProfile")
2. Determine which RIB owns this screen (see below)
3. Read [references/templates.md](references/templates.md) for the 4 file templates
4. Substitute `{ScreenName}`, `{screenName}`, and `{RibName}` throughout
5. Create folder: `tyfe-ios-app/Core/{ScreenName}/`
6. Create all 4 files in that folder

## Determining the RIB

The app may have one or more RIBs (e.g., Core, Onboarding, TabBar). Each RIB has its own Router, Interactor, and Builder.

To determine which RIB:
1. Check `Root/RIBs/` for existing RIBs — look at the folder names
2. Look at existing screens in the same flow (e.g., if adding an onboarding screen, check where other onboarding screens are wired)
3. If only one RIB exists (Core), use that
4. If unclear, ask the user

The `{RibName}` placeholder defaults to `Core` — substitute with the actual RIB name (e.g., `Onboarding`, `TabBar`).

## File Layout

All 4 files go in `Core/{ScreenName}/`:

| File | Contains |
|------|----------|
| `{ScreenName}View.swift` | Delegate struct, View struct, Preview, `{RibName}Builder` extension, `{RibName}Router` extension |
| `{ScreenName}Presenter.swift` | `@Observable @MainActor` presenter class, `Event` enum for analytics |
| `{ScreenName}Router.swift` | Protocol extending `GlobalRouter`, `{RibName}Router` conformance |
| `{ScreenName}Interactor.swift` | Protocol extending `GlobalInteractor`, `{RibName}Interactor` conformance |

## Key Patterns

- The `{RibName}Builder` and `{RibName}Router` extensions live **in the View file**, not in the RIB's own files
- The Delegate struct lives at the top of the View file — add properties the screen needs from its caller
- The Presenter owns `interactor` and `router` as `private let` — typed to the screen's protocols, not the RIB types
- Router and Interactor protocols start empty — add methods as the screen's requirements emerge
- Analytics: `onViewAppear` calls `interactor.trackScreenEvent`, all other events call `interactor.trackEvent`
- Event names follow pattern: `{ScreenName}View_{Action}` (e.g., `SettingsView_Appear`)

## After Scaffolding

Once the skeleton is created, build out the screen by:
- Adding UI to the View's `body`
- Adding state properties and action methods to the Presenter
- Adding data access methods to the Interactor protocol + `{RibName}Interactor` extension
- Adding navigation methods to the Router protocol (`{RibName}Router` already conforms)
- Adding Delegate properties if the screen needs data from its caller
