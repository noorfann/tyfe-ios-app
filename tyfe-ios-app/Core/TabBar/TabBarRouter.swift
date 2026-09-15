import SwiftUI

@MainActor
protocol TabBarRouter {
    func showFocusOverlay(delegate: FocusDelegate, tabSelectionAction: TabSelectionAction)
}

extension CoreRouter: TabBarRouter {

    func showFocusOverlay(delegate: FocusDelegate, tabSelectionAction: TabSelectionAction) {
        router.showScreen(.fullScreenCover) { router in
            builder.focusView(router: router, delegate: delegate)
                .environment(\.selectTab, tabSelectionAction)
        }
    }
}
