# VIPER + RIBs Architecture

This project uses VIPER per screen with a single RIB (CoreRouter, CoreInteractor, CoreBuilder) for the entire app.

## Data Flow

IMPORTANT: Never skip layers. This is the strict data flow:

```
View → Presenter → Interactor → Manager
View ← Presenter ← Interactor ← Manager
```

- View displays data from Presenter and calls Presenter methods
- Presenter calls Interactor for data and Router for navigation
- Interactor accesses Managers via DependencyContainer
- Router handles navigation only

## View Layer

- `@State var presenter: HomePresenter` — holds the Presenter (not `@StateObject`, not `@ObservedObject`)
- `@State private var ...` — allowed for local UI animation state only
- NEVER put business logic in button closures — call a Presenter method instead
- NEVER access Interactors or Managers directly

## Presenter Layer

- `@Observable @MainActor class HomePresenter`
- Owns ALL business logic and screen state
- Calls `interactor` for data, `router` for navigation
- NEVER accesses Managers directly — always go through Interactor
- Analytics are tracked here in the Presenter — NEVER in the View
- Every user-facing method MUST track analytics via `interactor.trackEvent(event:)`

## RIBs Architecture

The app is organized into RIBs (Router, Interactor, Builder) modules. Currently there is one RIB — Core (CoreRouter, CoreInteractor, CoreBuilder) — but the app can be split into multiple RIBs (e.g., OnboardingRouter/OnboardingInteractor, TabBarRouter/TabBarInteractor). Each RIB owns a set of screens and their shared routing/data methods.

## Router and Interactor Are Protocols

Each screen's Presenter holds `router` and `interactor` as protocol types (e.g., `HomeRouter`, `HomeInteractor`). The actual implementations are extensions on the RIB's concrete class (e.g., `CoreRouter`, `CoreInteractor`). NEVER add a method to a screen's protocol that won't be implemented on the RIB's Router/Interactor. Only declare methods that will exist as extensions on the concrete RIB class.

## Router Layer

- Protocol extending `GlobalRouter`, implemented by `CoreRouter`
- ALL navigation uses SwiftfulRouting: `router.showScreen()`, `router.showAlert()`, `router.showModule()`
- Before creating a new route method, search for existing `func show[ScreenName]` in the codebase
- Router protocol must declare all methods the screen needs, even if the CoreRouter extension exists elsewhere
- NEVER duplicate CoreRouter extension implementations — reuse existing ones

## Interactor Layer

- Protocol extending `GlobalInteractor`, implemented by `CoreInteractor`
- Data access only — resolves Managers from `container`
- No UI logic, no business logic, no navigation
- May chain calls across multiple managers (e.g., get userId from AuthManager then pass to another manager)

## Delegates (Passing Data Between Screens)

IMPORTANT: Delegates are the mechanism for passing data between screens. They are structs held by the View, NEVER by the Presenter.

- Prefer fetching data via Interactor over passing it through delegates. Delegates are only for data that exists in memory between screens and is NOT available through the manager/database layer (e.g., onboarding flow selections, UI configuration, callbacks). If the data can be fetched from a manager or database, fetch it in the Presenter via Interactor instead.
- Define a `struct XDelegate` in the same file as the View, with an `eventParameters` computed property for analytics
- The **View holds** the delegate as `let delegate: XDelegate`
- The **View passes** the delegate to the Presenter through method parameters: `presenter.onViewAppear(delegate: delegate)`
- The **Presenter NEVER stores** the delegate — it only receives it as a method parameter
- NEVER inject delegate data into the Presenter through `init` — the Presenter init only takes `interactor` and `router`
- When navigating to the next screen, the Presenter creates the next screen's delegate with relevant data and passes it to the Router

```swift
// Delegate definition (in the View file)
struct DetailDelegate {
    var item: ItemModel

    var eventParameters: [String: Any]? {
        item.eventParameters
    }
}

// View — holds delegate, passes to Presenter via methods
struct DetailView: View {
    @State var presenter: DetailPresenter
    let delegate: DetailDelegate

    var body: some View {
        Text(delegate.item.title)          // View can read delegate for display
            .onAppear {
                presenter.onViewAppear(delegate: delegate)  // Pass to Presenter
            }
    }
}

// Presenter — receives delegate per method, NEVER stores it
@Observable @MainActor
class DetailPresenter {
    private let interactor: DetailInteractor
    private let router: DetailRouter

    init(interactor: DetailInteractor, router: DetailRouter) {
        self.interactor = interactor
        self.router = router
        // NO delegate here
    }

    func onViewAppear(delegate: DetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
}

// Builder — passes delegate to View, NOT to Presenter
extension CoreBuilder {
    func detailView(router: AnyRouter, delegate: DetailDelegate) -> some View {
        DetailView(
            presenter: DetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}
```

## Components (Reusable Views)

Components are NOT screens. They are child views used WITHIN screen Views. A screen View composes Components by passing data from the Presenter down and wiring closures back to Presenter methods.

IMPORTANT: Components are DUMB UI. They receive data and fire callbacks. Nothing else.

- NO `@State` for data (only for local UI animations)
- NO `@Observable` objects or Presenters
- ALL data injected via init — make properties optional for flexibility
- ALL actions injected as closures: `var onTap: (() -> Void)?`
- ALL loading/error states injected as parameters
- Create multiple `#Preview` blocks (full data, partial, loading, empty)

## Registration

New screens register in 3 places within their RIB. The CoreRouter and CoreBuilder extensions live at the **bottom of the View file** — NOT in the Router file. The Router file only contains the protocol conformance.

1. **View file** (e.g., `PaywallView.swift`) — contains the View, the Delegate struct, AND the `extension CoreRouter` with `func showScreenName()` AND the `extension CoreBuilder` with the factory method. These are the ONLY definitions — NEVER create duplicates elsewhere.
2. **Router file** (e.g., `PaywallRouter.swift`) — contains ONLY the Router protocol and `extension CoreRouter: PaywallRouter { }` conformance. No `showX` implementations here.
3. **Interactor extension** (e.g., `CoreInteractor`) — data access methods the screen needs

IMPORTANT: Before adding a routing method, ALWAYS search the codebase for `func show[ScreenName]` to check if it already exists. They typically live in the View file but can be in any file as extensions. Each `showX` method must be defined exactly once — NEVER create a duplicate unless the user explicitly says to.

If the app has multiple RIBs, register in the RIB that owns the screen. Check existing screens in the same flow to determine which RIB to use.
