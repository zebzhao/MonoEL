
import UIKit

extension UILabel {
    func fadeIn(toAlpha: CGFloat = 1.0) {
        UIView.animate(withDuration: 0.3, delay: 0.2, options: UIView.AnimationOptions.curveEaseOut, animations: {
            self.alpha = toAlpha
        }, completion: nil)
    }

    func fadeOut() {
        UIView.animate(withDuration: 0.3, delay: 0.0, options: UIView.AnimationOptions.curveEaseIn, animations: {
            self.alpha = 0.0
        }, completion: nil)
    }
}
