//
//  BlurIconView.swift
//  Nebula
//
//  Created by Zeb Zhao on 7/21/19.
//  Copyright © 2019 Simon Gladman. All rights reserved.
//

import UIKit
import PocketSVG

class BlurIconView: UIVisualEffectView
{
    var isShown = false
    var isActive = false
    
    private let blurEffect = UIBlurEffect(style: .light)
    private let activeBlurEffect = UIBlurEffect(style: .extraLight)
    private let maskLayer = CAShapeLayer()
    private let showAnimation = CABasicAnimation(keyPath: "path")
    private let hideAnimation = CABasicAnimation(keyPath: "path")
    
    init(forResource: String, x: CGFloat, y: CGFloat) {
        super.init(effect: blurEffect)
        
        let iconSvgUrl = Bundle.main.url(forResource: forResource, withExtension: "svg")!
        let iconSvgPath = SVGBezierPath.pathsFromSVG(at: iconSvgUrl)[0]
        let iconSvgPathEmpty = UIBezierPath(cgPath: iconSvgPath.cgPath)
        iconSvgPathEmpty.scaleAroundCenter(factor: 0)
        
        let svgPath = UIBezierPath()
        svgPath.usesEvenOddFillRule = true
        svgPath.move(to: CGPoint(x: x, y: y))
        svgPath.append(iconSvgPath)
        let svgPathEmpty = UIBezierPath()
        svgPathEmpty.usesEvenOddFillRule = true
        svgPathEmpty.move(to: CGPoint(x: x, y: y))
        svgPathEmpty.append(iconSvgPathEmpty)
        
        showAnimation.toValue = svgPath.cgPath
        showAnimation.duration = 0.3
        showAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        showAnimation.fillMode = CAMediaTimingFillMode.forwards
        showAnimation.isRemovedOnCompletion = false
        
        hideAnimation.fromValue = svgPath.cgPath
        hideAnimation.toValue = svgPathEmpty.cgPath
        hideAnimation.duration = 0.3
        hideAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        hideAnimation.fillMode = CAMediaTimingFillMode.forwards
        hideAnimation.isRemovedOnCompletion = false

        maskLayer.path = svgPathEmpty.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        self.frame = CGRect(x: x, y: y, width: 76, height: 76)
        self.layer.mask = maskLayer
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show(activate: Bool = false) {
        if (!isActive && activate) {
            isActive = true
            UIView.animate(withDuration: 0.3) {
                self.effect = self.activeBlurEffect
            }
        }
        guard !isShown else {return}
        isShown = true
        maskLayer.add(showAnimation, forKey: showAnimation.keyPath)
        
    }
    
    public func hide() {
        if (isActive) {
            isActive = false
            UIView.animate(withDuration: 0.3) {
                self.effect = self.blurEffect
            }
        }
        guard isShown else {return}
        isShown = false
        maskLayer.add(hideAnimation, forKey: hideAnimation.keyPath)
    }
}
