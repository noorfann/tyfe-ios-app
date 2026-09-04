---
name: creating-manager
description: Scaffold a new manager with service protocol, Mock/Prod service implementations, register in Dependencies.swift, and resolve in the appropriate RIB's Interactor. Use when the user asks to create a new manager, add a new service, or scaffold a new manager module.
---

# Creating Manager

Scaffold a complete manager module with protocol-based services and wire it into the dependency system.

## Steps

1. Get the manager name from the user (PascalCase, e.g., "Notification", "Payment", "Chat")
2. Read [references/templates.md](references/templates.md) for the 4 file templates + registration snippets
3. Determine which RIB owns this manager (see below)
4. Substitute `{ManagerName}`, `{managerName}`, and `{RibName}` throughout
5. Determine the folder location (see below)
6. Create all 4 files
7. Register in Dependencies.swift and `{RibName}Interactor.swift`

## Determining the RIB

The app may have one or more RIBs (e.g., Core, Onboarding, TabBar). Each RIB has its own Interactor where managers are resolved.

1. Check `Root/RIBs/` for existing RIBs — look at the folder names
2. If only one RIB exists (Core), use that
3. If multiple RIBs exist, determine which one needs this manager based on the flow it supports
4. If unclear, ask the user

The `{RibName}` placeholder defaults to `Core` — substitute with the actual RIB name.

## Folder Location

Managers live in `tyfe-ios-app/Managers/`. Each manager gets its own folder with a `Services/` subfolder:

```text
Managers/
  {ManagerName}/
    {ManagerName}Manager.swift
    Services/
      {ManagerName}Service.swift
      Mock{ManagerName}Service.swift
      Prod{ManagerName}Service.swift
```

Check existing managers in `Managers/` for reference.

## Registration

Every new manager must be registered in **2 places** — see the registration snippets in templates.md.

### Dependencies.swift

1. Add `let {managerName}Manager: {ManagerName}Manager` declaration at the top of `init()`
2. In the `.mock` switch arm: create with `Mock{ManagerName}Service()`
3. In the `.dev, .prod` arm: create with `Prod{ManagerName}Service()`
4. After the switch: `container.register({ManagerName}Manager.self, service: {managerName}Manager)`
5. Follow initialization order — `LogManager` and `AuthManager` are created first, all others come after

### {RibName}Interactor.swift

1. Add `private let {managerName}Manager: {ManagerName}Manager` property
2. In `init(container:)`: `self.{managerName}Manager = container.resolve({ManagerName}Manager.self)!`

## Key Patterns

- Manager is `@MainActor @Observable` — always
- Manager takes `LogManager?` as optional dependency — always
- Manager takes its service protocol in `init` — the protocol, not a concrete implementation
- Service protocol is `@MainActor protocol ... : Sendable`
- MockService is a `class` (mutable state for testing) — production service is a `struct` (unless it needs mutable state)
- Production service naming: use the SDK/vendor name if it wraps a specific third-party (e.g., `FirebaseAvatarService`, `RevenueCatPurchaseService`). Use `Prod{ManagerName}Service` only if generic
- Manager includes `enum Event: LoggableEvent` for analytics — event names follow `{ManagerName}Man_Action_Status` pattern
- Managers are flexible — do NOT force signIn/signOut, state properties, or sync engines unless the user requests them
- If the manager needs database syncing, use `DocumentSyncEngine` or `CollectionSyncEngine` composition (see `manager-lifecycle` rules)

## After Scaffolding

Once the skeleton is created, the user will likely want to:
- Add methods to the service protocol + both Mock/Prod implementations
- Add state properties to the manager
- Add manager methods that call through to the service
- Add Event cases for analytics tracking
- Expose manager methods in `{RibName}Interactor` as interactor methods
- If the manager needs signIn/signOut, add those methods and wire into the interactor's `logIn()`/`signOut()`
