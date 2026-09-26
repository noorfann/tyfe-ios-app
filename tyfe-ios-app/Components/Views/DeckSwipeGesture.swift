import SwiftUI
import UIKit

struct DeckSwipeGesture: UIGestureRecognizerRepresentable {

    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void
    let onCancelled: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        recognizer.cancelsTouchesInView = true
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self)
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard let view = recognizer.view else { return }

        switch recognizer.state {
        case .began:
            onBegan()
        case .changed:
            onChanged(recognizer.translation(in: view).x)
        case .ended:
            onEnded(
                recognizer.translation(in: view).x,
                recognizer.velocity(in: view).x
            )
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var parent: DeckSwipeGesture

        init(parent: DeckSwipeGesture) {
            self.parent = parent
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = panGestureRecognizer.view else {
                return false
            }

            let translation = panGestureRecognizer.translation(in: view)
            if translation != .zero {
                return abs(translation.x) > abs(translation.y)
            }

            let velocity = panGestureRecognizer.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}
