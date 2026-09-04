import Foundation
import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard UINavigationController.allowsSwipeBack else {
            return false
        }

        return viewControllers.count > 1
    }

    static private(set) var allowsSwipeBack: Bool = true

    static func setSwipeBack(enabled: Bool) {
        allowsSwipeBack = enabled
    }
}
