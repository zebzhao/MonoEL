// https://stackoverflow.com/questions/20400396/reposition-resize-uibezierpath

import UIKit

extension UIBezierPath
{
    
    func scaleAroundCenter(factor: CGFloat)
    {
        let beforeCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // SCALE path by factor
        let scaleTransform = CGAffineTransform(scaleX: factor, y: factor)
        self.apply(scaleTransform)
        
        let afterCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        let diff = CGPoint(
            x: beforeCenter.x - afterCenter.x,
            y: beforeCenter.y - afterCenter.y)
        
        let translateTransform = CGAffineTransform(translationX: diff.x, y: diff.y)
        self.apply(translateTransform)
    }
    
}
