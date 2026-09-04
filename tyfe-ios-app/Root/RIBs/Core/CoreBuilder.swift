import SwiftUI
import SwiftfulUI

@MainActor
struct CoreBuilder: Builder {
    let interactor: CoreInteractor
    
    func build() -> AnyView {
        appView().any()
    }
}
