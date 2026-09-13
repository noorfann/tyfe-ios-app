import SwiftUI

@MainActor
protocol TabBarRouter {
    func showFocusOverlay(delegate: FocusDelegate)
}

extension CoreRouter: TabBarRouter {

    func showFocusOverlay(delegate: FocusDelegate) {
        router.showScreen(.fullScreenCover) { router in
            builder.focusView(router: router, delegate: delegate)
        }
    }
}
