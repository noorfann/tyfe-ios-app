---
name: refactoring-screen
description: Rename a VIPER screen across all files including View, Presenter, Interactor, Router, Delegate, CoreBuilder extension, CoreRouter extension, event name strings, and cross-references from other screens. Use when the user asks to rename, refactor, or change the name of a screen.
---

# Refactoring Screen

Rename a VIPER screen across all files. This is a mechanical find-and-replace across 4+ files, plus cross-references.

## Steps

1. Get the current screen name and new screen name (PascalCase, e.g., `Home` → `Dashboard`)
2. Search for all references to the old name across the codebase
3. Rename files and folder
4. Update all internal references
5. Update all cross-references from other screens

## Files to Update

Every screen has 4 files in `Core/{ScreenName}/`:

| File | Contains |
|------|----------|
| `{ScreenName}View.swift` | View struct, Delegate struct, CoreBuilder extension, CoreRouter extension |
| `{ScreenName}Presenter.swift` | Presenter class, Event enum with event name strings |
| `{ScreenName}Interactor.swift` | Interactor protocol, CoreInteractor conformance |
| `{ScreenName}Router.swift` | Router protocol, CoreRouter conformance |

## What to Rename

### In all 4 files — replace `{OldName}` with `{NewName}`:

- Struct/class/protocol names: `{OldName}View`, `{OldName}Presenter`, `{OldName}Interactor`, `{OldName}Router`
- Delegate struct: `{OldName}Delegate`
- Builder method: `func {oldName}View(` → `func {newName}View(`
- Router method: `func show{OldName}View(` → `func show{NewName}View(`

### In Presenter — update event name strings:

```swift
// Old:
return "{OldName}View_Appear"
return "{OldName}View_Disappear"

// New:
return "{NewName}View_Appear"
return "{NewName}View_Disappear"
```

### Navigation title (if applicable):

```swift
// Old:
.navigationTitle("{OldName}")

// New:
.navigationTitle("{NewName}")
```

### Rename files:

- `{OldName}View.swift` → `{NewName}View.swift`
- `{OldName}Presenter.swift` → `{NewName}Presenter.swift`
- `{OldName}Interactor.swift` → `{NewName}Interactor.swift`
- `{OldName}Router.swift` → `{NewName}Router.swift`

### Rename folder:

- `Core/{OldName}/` → `Core/{NewName}/`

### Screen-specific components (if they exist):

If `Core/{OldName}/Components/` exists, rename the folder and update any component names that include the old screen name.

## Cross-References

Search the entire codebase for references to the old screen name. Common locations:

- **Other screens' presenters** calling `router.show{OldName}View()`
- **AppView.swift** — tab bar setup referencing `builder.{oldName}View()`
- **Tab titles** — `TabBarTab(title: "{OldName}", ...)`
- **Other router protocols** that include navigation to this screen

Use grep to find all occurrences:

```
{OldName}View
{OldName}Presenter
{OldName}Interactor
{OldName}Router
{OldName}Delegate
{oldName}View(
show{OldName}View
```

## Execution Order

1. **Search first** — grep for all `{OldName}` references across the codebase before making changes
2. **Rename folder** — `Core/{OldName}/` → `Core/{NewName}/`
3. **Rename files** — all 4 files within the folder
4. **Update file contents** — replace all references in the 4 screen files
5. **Update cross-references** — fix references in other files found during search
6. **Verify** — grep again to confirm no remaining references

## Key Patterns

- **Always search first** — grep the entire codebase before renaming to find all references
- **Event name strings are separate** — they use string literals like `"{OldName}View_Appear"`, not computed from the type name
- **Builder methods use camelCase** — `{oldName}View()` not `{OldName}View()`
- **Router methods use PascalCase** — `show{OldName}View()`
- **Delegate may not exist** — some screens (like Settings) don't have a Delegate struct
- **CoreBuilder and CoreRouter extensions live in the View file** — not separate files
