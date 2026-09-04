# VIPER Screen Templates

Substitute `{ScreenName}` (PascalCase), `{screenName}` (camelCase), and `{RibName}` (PascalCase, defaults to "Core") throughout.

## File 1: {ScreenName}View.swift

```swift
import SwiftUI
import SwiftfulUI

struct {ScreenName}Delegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct {ScreenName}View: View {

    @State var presenter: {ScreenName}Presenter
    let delegate: {ScreenName}Delegate

    var body: some View {
        Text("Hello, World!")
            .onAppear {
                presenter.onViewAppear(delegate: delegate)
            }
            .onDisappear {
                presenter.onViewDisappear(delegate: delegate)
            }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = {RibName}Interactor(container: container)
    let builder = {RibName}Builder(interactor: interactor)
    let delegate = {ScreenName}Delegate()

    return RouterView { router in
        builder.{screenName}View(router: router, delegate: delegate)
    }
}

extension {RibName}Builder {

    func {screenName}View(router: AnyRouter, delegate: {ScreenName}Delegate) -> some View {
        {ScreenName}View(
            presenter: {ScreenName}Presenter(
                interactor: interactor,
                router: {RibName}Router(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension {RibName}Router {

    func show{ScreenName}View(delegate: {ScreenName}Delegate) {
        router.showScreen(.push) { router in
            builder.{screenName}View(router: router, delegate: delegate)
        }
    }

}
```

## File 2: {ScreenName}Presenter.swift

```swift
import SwiftUI

@Observable
@MainActor
class {ScreenName}Presenter {

    private let interactor: {ScreenName}Interactor
    private let router: {ScreenName}Router

    init(interactor: {ScreenName}Interactor, router: {ScreenName}Router) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: {ScreenName}Delegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: {ScreenName}Delegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension {ScreenName}Presenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: {ScreenName}Delegate)
        case onDisappear(delegate: {ScreenName}Delegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "{ScreenName}View_Appear"
            case .onDisappear:              return "{ScreenName}View_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }

}
```

## File 3: {ScreenName}Router.swift

```swift
import SwiftUI

@MainActor
protocol {ScreenName}Router: GlobalRouter {

}

extension {RibName}Router: {ScreenName}Router { }
```

## File 4: {ScreenName}Interactor.swift

```swift
import SwiftUI

@MainActor
protocol {ScreenName}Interactor: GlobalInteractor {

}

extension {RibName}Interactor: {ScreenName}Interactor { }
```
