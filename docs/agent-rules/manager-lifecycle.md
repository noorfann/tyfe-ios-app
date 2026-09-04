# Manager Lifecycle

How managers are created, registered, coordinated during login/logout, and tracked with analytics.

## Manager Structure

- All managers are `@MainActor @Observable`
- All managers take `LogManager` as optional dependency
- Managers are flexible — some need `signIn`/`signOut`, some don't; some hold state, some don't
- Do not force any method or pattern onto a manager — add only what the manager actually needs
- Managers may own one or many sync engines (`DocumentSyncEngine`, `CollectionSyncEngine`) from SwiftfulDataManagers for easy database document/collection syncing, but don't have to
- Managers typically wrap a protocol-based service (Mock/Prod implementations)

## Registration (2 Places)

IMPORTANT: Every new manager must be registered in both places.

### 1. Dependencies.swift

- Create manager with appropriate service for each `BuildConfiguration` (mock/dev/prod)
- `.mock` case uses Mock services; `.dev, .prod` share one switch arm (branch only on LogManager console service and ABTestManager service)
- Register in `DependencyContainer` after creation
- Data sync managers use `container.register(Type.self, key: config.managerKey, service:)` — keys are needed because the container may hold multiple instances of the same type (e.g., multiple `ProgressManager` tracking different data)
- Service managers use `container.register(Type.self, service:)` — no key needed because most concrete types are one-off with no duplicates
- `DevPreview` delegates to `Dependencies(config: .mock(isSignedIn:, addLogging: false))` — no separate registration needed

### 2. CoreInteractor.swift

- Resolve from container in `init(container:)`
- Data sync managers resolve with key: `container.resolve(Type.self, key: config.managerKey)!`
- Service managers resolve without key: `container.resolve(Type.self)!`
- Expose manager methods as Interactor methods (Presenters never access managers directly)

## Login Coordination

Login is orchestrated in `CoreInteractor.logIn()` using `async let` for parallel execution.

```
async let userLogin = userManager.signIn(auth:isNewUser:)
async let purchaseLogin = purchaseManager.logIn(userId:)
async let streakLogin = streakManager.logIn(userId:)
...
let (_, _, _, ...) = await (try userLogin, try purchaseLogin, try streakLogin, ...)
```

- All data sync managers with `signIn`/`logIn` must be added here
- Service managers and config managers do NOT participate in login
- After all logins complete: add user properties to LogManager

When adding a new data sync manager:
1. Add `async let` line in `logIn()` with the manager's signIn method
2. Add to the tuple `await` line
3. Add `signOut()`/`logOut()` call in `signOut()` method

## Logout Coordination

Logout is orchestrated in `CoreInteractor.signOut()` — sequential, not parallel.

```
1. authManager.signOut()        ← clears auth state first
2. purchaseManager.logOut()     ← async cleanup
3. userManager.signOut()        ← removes listeners, clears cache
4. streakManager.logOut()       ← clears gamification state
5. xpManager.logOut()
6. progressManager.logOut()
```

- AuthManager signs out FIRST (clears auth state)
- Remaining managers clean up after
- Each manager's `signOut()`/`logOut()` must cancel listeners and clear cached data

## Delete Account

`CoreInteractor.deleteAccount()` handles account deletion:

1. Reauthenticate user (Apple/Google/Anonymous)
2. Delete user data from Firestore INSIDE the auth closure (before auth is revoked) — though prefer moving deletion logic to a backend function if one exists
3. Log out of PurchaseManager
4. Delete LogManager user profile

IMPORTANT: Firestore deletion must happen before auth revocation — security rules may block access after.

## Analytics Tracking

- Every manager method MUST track analytics via `logger?.trackEvent(event:)`
- Each manager has an internal `enum Event: DataLogEvent` (or `LoggableEvent`)
- Event naming: `ManagerNameMan_ActionName_Status` (e.g., `UserMan_SignIn_Start`, `UserMan_SignIn_Success`)
- Track start AND success/fail for async operations
- Event enum must include `eventName`, `parameters`, and `type` (`.analytic`, `.info`, `.severe`)

## Sync Engine Pattern

Managers that own sync engines call through to the engine:

- `signIn(id:)` — calls engine's `startListener` to begin syncing + local persistence
- `signOut()` — calls engine's `stopListener` to cancel syncing + clear cache
- Both must track analytics
- Not all managers use sync engines — only add when the manager needs to sync database documents/collections

## Initialization Order

In `Dependencies.init()`:
1. `LogManager` created first (other managers depend on it for logging)
2. `AuthManager` created next (other managers may need auth state)
3. All other managers created (order doesn't matter — no cross-dependencies at init)
4. All managers registered in `DependencyContainer`
