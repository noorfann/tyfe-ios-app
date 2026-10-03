import SwiftUI
import UIKit

/// A push cannot use interactiveDismissDisabled alone: UIKit's edge swipe also needs a guard.
struct ProfileNavigationExitGuard: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.disablePopGesture() }
    static func dismantleUIViewController(_ controller: Controller, coordinator: Void) { controller.restorePopGesture() }

    final class Controller: UIViewController {
        private weak var guardedGesture: UIGestureRecognizer?
        private var originalEnabled: Bool?

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            disablePopGesture()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            disablePopGesture()
        }

        func disablePopGesture() {
            guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
            if guardedGesture !== gesture {
                restorePopGesture()
                originalEnabled = gesture.isEnabled
                guardedGesture = gesture
            }
            gesture.isEnabled = false
        }

        func restorePopGesture() {
            if let originalEnabled { guardedGesture?.isEnabled = originalEnabled }
            originalEnabled = nil
            guardedGesture = nil
        }
    }
}
