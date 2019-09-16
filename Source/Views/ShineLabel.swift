//
//  ShineLabel.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/12/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import UIKit

class ShineLabel: UILabel {
    
    /*
     // Only override drawRect: if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func drawRect(rect: CGRect) {
     // Drawing code
     }
     */
    
    var shineDuration : CFTimeInterval = 0
    var fadeoutDuration : CFTimeInterval = 0
    var autoStart: Bool = false
    var isShining : Bool {
        get {
            return !self.displaylink!.isPaused
        }
    }
    var isVisible : Bool {
        get {
            return self.isFadedOut == false
        }
    }
    
    private var attributedStringCopy: NSMutableAttributedString?
    private var characterAnimationDurations = [CFTimeInterval]()
    private var characterAnimationDelays = [CFTimeInterval]()
    private var displaylink: CADisplayLink?
    private var beginTime: CFTimeInterval = 0
    private var isFadedOut: Bool
    private var completion: (() -> Void)?
    private var textCopy: String?
    
    override internal var text: String? {
        set {
            textCopy = newValue
            if let value=newValue {
                self.attributedText = NSMutableAttributedString(string: value)
            } else {
                self.attributedText = nil
            }
        }
        get {
            return textCopy
        }
    }
    
    override internal var attributedText: NSAttributedString? {
        set {
            attributedStringCopy = self.initialAttributedString(attributedString: newValue)
            super.attributedText = attributedStringCopy
            
            if let stringValue = attributedStringCopy {
                for index in 0..<stringValue.length {
                    let delay = Double(arc4random_uniform(UInt32(shineDuration / 2 * 100))) / 100.0
                    characterAnimationDelays.insert(delay, at: index)
                    let remain = shineDuration - delay
                    characterAnimationDurations.insert(Double(arc4random_uniform(UInt32(remain * 100))) / 100.0, at: index)
                }
            }
        }
        get {
            return attributedStringCopy
        }
    }
    convenience init() {
        self.init(frame:CGRect.zero)
    }
    
    override init(frame: CGRect) {
        shineDuration = 2.5
        fadeoutDuration = 2.5
        autoStart = false
        isFadedOut = true
        super.init(frame: frame)
        initSelf()
    }
    
    required init?(coder aDecoder: NSCoder) {
        shineDuration = 2.5
        fadeoutDuration = 2.5
        autoStart = false
        isFadedOut = true
        super.init(coder: aDecoder)
        initSelf()
    }
    
    private func initSelf() {
        self.textColor = UIColor.white
        displaylink = CADisplayLink(target: self, selector:#selector(updateAttributedString))
        displaylink!.isPaused = true
        displaylink!.add(to: .current, forMode: .common)
    }
    
    override func didMoveToWindow() {
        if (self.window != nil) && self.autoStart {
            self.shine()
        }
    }
    
    @objc internal func updateAttributedString() {
        let now = CACurrentMediaTime()
        for index in 0...attributedStringCopy!.length - 1 {
            
            attributedStringCopy!.enumerateAttribute(NSAttributedString.Key.foregroundColor, in: NSMakeRange(index, 1), options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                
                let currentAlpha = (value as AnyObject).cgColor?.alpha ?? 1.0
                let checkAlpha = (self.isFadedOut && (currentAlpha > 0)) || (!self.isFadedOut && (currentAlpha < 1))
                let shouldUpdateAlpha : Bool = checkAlpha || (now - self.beginTime) >= self.characterAnimationDelays[index]
                if !shouldUpdateAlpha {
                    return
                }
                
                var percentage = (now - self.beginTime - self.characterAnimationDelays[index]) / (self.characterAnimationDurations[index])
                if (self.isFadedOut) {
                    percentage = 1 - percentage
                }
                
                let color = self.textColor.withAlphaComponent(CGFloat(percentage))
                self.attributedStringCopy!.addAttributes([.foregroundColor : color], range: range)
            })
        }
        
        super.attributedText = attributedStringCopy
        if now > beginTime + shineDuration {
            displaylink!.isPaused = true
            if self.completion != nil {
                self.completion!()
            }
        }
    }
    
    
    internal func initialAttributedString(attributedString: NSAttributedString?) -> NSMutableAttributedString? {
        if attributedString == nil {
            return nil
        }
        
        let mutableAttributedString = attributedString!.mutableCopy() as! NSMutableAttributedString
        let color = textColor.withAlphaComponent(0)
        mutableAttributedString.addAttributes([.foregroundColor : color], range: NSMakeRange(0, mutableAttributedString.length))
        
        return mutableAttributedString
    }
    
    func shine(completion: (() -> Void)? = nil) {
        if !self.isShining && self.isFadedOut {
            self.completion = completion
            isFadedOut = false
            startAnimation(duration: fadeoutDuration)
        }
    }
    
    func fade(completion: (() -> Void)? = nil) {
        if !self.isShining && !self.isFadedOut {
            self.completion = completion
            isFadedOut = true
            startAnimation(duration: fadeoutDuration)
        }
    }
    
    func startAnimation(duration: CFTimeInterval) {
        beginTime = CACurrentMediaTime()
        displaylink!.isPaused = false
    }
}
