//
//  MTSlideToOpenControl.swift
//  MTSlideToOpen
//
//  Created by Martin Lee on 10/12/17.
//  Copyright © 2017 Martin Le. All rights reserved.
//

/*
 The MIT License (MIT)
 
 Copyright (c) 2017 Tien Le
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import UIKit

@objc public protocol MTSlideToOpenDelegate {
    func mtSlideToOpenDelegateDidFinish(_ sender: MTSlideToOpenView)
}

@objcMembers public class MTSlideToOpenView: UIView {
    // MARK: All Views
    public let textLabel: UILabel = {
        let label = UILabel.init()
        return label
    }()
    public let sliderTextLabel: UILabel = {
        let label = UILabel()
        return label
    }()
    public let thumbnailImageView: UIImageView = {
        let view = MTRoundImageView()
        view.isUserInteractionEnabled = true
        view.contentMode = .center
        return view
    }()
    public let sliderHolderView: UIView = {
        let view = UIView()
        return view
    }()
    public let draggedView: UIView = {
        let view = UIView()
        return view
    }()
    public let view: UIView = {
        let view = UIView()
        return view
    }()
    // MARK: Public properties
    public weak var delegate: MTSlideToOpenDelegate?
    public var animationVelocity: Double = 0.2
    public var sliderViewTopDistance: CGFloat = 8.0 {
        didSet {
            topSliderConstraint?.constant = sliderViewTopDistance
            layoutIfNeeded()
        }
    }
    public var thumbnailViewTopDistance: CGFloat = 0.0 {
        didSet {
            topThumbnailViewConstraint?.constant = thumbnailViewTopDistance
            layoutIfNeeded()
        }
    }
    public var thumbnailViewStartingDistance: CGFloat = 0.0 {
        didSet {
            leadingThumbnailViewConstraint?.constant = thumbnailViewStartingDistance
            trailingDraggedViewConstraint?.constant = thumbnailViewStartingDistance
            setNeedsLayout()
        }
    }
    public var textLabelLeadingDistance: CGFloat = 0 {
        didSet {
            leadingTextLabelConstraint?.constant = textLabelLeadingDistance
            setNeedsLayout()
        }
    }
    public var isEnabled:Bool = true {
        didSet {
            animationChangedEnabledBlock?(isEnabled)
        }
    }
    public var showSliderText:Bool = false {
        didSet {
            sliderTextLabel.isHidden = !showSliderText
        }
    }
    public var animationChangedEnabledBlock:((Bool) -> Void)?
    // MARK: Default styles
    public var sliderCornerRadious: CGFloat = 30.0 {
        didSet {
            sliderHolderView.layer.cornerRadius = sliderCornerRadious
            draggedView.layer.cornerRadius = sliderCornerRadious
        }
    }
    public var defaultSliderBackgroundColor: UIColor = UIColor(red:0.1, green:0.61, blue:0.84, alpha:0.1) {
        didSet {
            sliderHolderView.backgroundColor = defaultSliderBackgroundColor
            sliderTextLabel.textColor = defaultSliderBackgroundColor
        }
    }
    
    public var defaultSlidingColor:UIColor = UIColor(red:25.0/255, green:155.0/255, blue:215.0/255, alpha:0.7) {
        didSet {
            draggedView.backgroundColor = defaultSlidingColor
            textLabel.textColor = defaultSlidingColor
        }
    }
    public var defaultThumbnailColor:UIColor = UIColor(red:25.0/255, green:155.0/255, blue:215.0/255, alpha:1) {
        didSet {
            thumbnailImageView.backgroundColor = defaultThumbnailColor
        }
    }
    public var defaultLabelText: String = "Swipe to open" {
        didSet {
            textLabel.text = defaultLabelText
            sliderTextLabel.text = defaultLabelText
        }
    }
    public var textFont: UIFont = UIFont.systemFont(ofSize: 15.0) {
        didSet {
            textLabel.font = textFont
            sliderTextLabel.font = textFont
        }
    }
    // MARK: Private Properties
    private var leadingThumbnailViewConstraint: NSLayoutConstraint?
    private var leadingTextLabelConstraint: NSLayoutConstraint?
    private var topSliderConstraint: NSLayoutConstraint?
    private var topThumbnailViewConstraint: NSLayoutConstraint?
    private var trailingDraggedViewConstraint: NSLayoutConstraint?
    private var xPositionInThumbnailView: CGFloat = 0
    private var xEndingPoint: CGFloat {
        get {
            return (self.view.frame.maxX - thumbnailImageView.bounds.width - thumbnailViewStartingDistance)
        }
    }
    private var isFinished: Bool = false
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        setupView()
    }
    
    private func setupView() {
        self.addSubview(view)
        view.addSubview(thumbnailImageView)
        view.addSubview(sliderHolderView)
        view.addSubview(draggedView)
        draggedView.addSubview(sliderTextLabel)
        sliderHolderView.addSubview(textLabel)
        view.bringSubviewToFront(self.thumbnailImageView)
        setupConstraint()
        setStyle()
        // Add pan gesture
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePanGesture(_:)))
        panGestureRecognizer.minimumNumberOfTouches = 1
        thumbnailImageView.addGestureRecognizer(panGestureRecognizer)
    }
    
    private func setupConstraint() {
        view.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        sliderHolderView.translatesAutoresizingMaskIntoConstraints = false
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderTextLabel.translatesAutoresizingMaskIntoConstraints = false
        draggedView.translatesAutoresizingMaskIntoConstraints = false
        // Setup for view
        view.leadingAnchor.constraint(equalTo: self.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: self.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        // Setup for circle View
        leadingThumbnailViewConstraint = thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        leadingThumbnailViewConstraint?.isActive = true
        topThumbnailViewConstraint = thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: thumbnailViewTopDistance)
        topThumbnailViewConstraint?.isActive = true
        thumbnailImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor).isActive = true
        // Setup for slider holder view
        topSliderConstraint = sliderHolderView.topAnchor.constraint(equalTo: view.topAnchor, constant: sliderViewTopDistance)
        topSliderConstraint?.isActive = true
        sliderHolderView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        sliderHolderView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        sliderHolderView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        // Setup for textLabel
        textLabel.topAnchor.constraint(equalTo: sliderHolderView.topAnchor).isActive = true
        textLabel.centerYAnchor.constraint(equalTo: sliderHolderView.centerYAnchor).isActive = true
        leadingTextLabelConstraint = textLabel.leadingAnchor.constraint(equalTo: sliderHolderView.leadingAnchor, constant: textLabelLeadingDistance)
        leadingTextLabelConstraint?.isActive = true
        textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: CGFloat(-8)).isActive = true
        // Setup for sliderTextLabel
        sliderTextLabel.topAnchor.constraint(equalTo: textLabel.topAnchor).isActive = true
        sliderTextLabel.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor).isActive = true
        sliderTextLabel.leadingAnchor.constraint(equalTo: textLabel.leadingAnchor).isActive = true
        sliderTextLabel.trailingAnchor.constraint(equalTo: textLabel.trailingAnchor).isActive = true
        // Setup for Dragged View
        draggedView.leadingAnchor.constraint(equalTo: sliderHolderView.leadingAnchor).isActive = true
        draggedView.topAnchor.constraint(equalTo: sliderHolderView.topAnchor).isActive = true
        draggedView.centerYAnchor.constraint(equalTo: sliderHolderView.centerYAnchor).isActive = true
        trailingDraggedViewConstraint = draggedView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: thumbnailViewStartingDistance)
        trailingDraggedViewConstraint?.isActive = true
    }
    
    private func setStyle() {
        thumbnailImageView.backgroundColor = defaultThumbnailColor
        textLabel.text = defaultLabelText
        textLabel.font = textFont
        textLabel.textColor = defaultSlidingColor
        textLabel.textAlignment = .center
        
        sliderTextLabel.text = defaultLabelText
        sliderTextLabel.font = textFont
        sliderTextLabel.textColor = defaultSliderBackgroundColor
        sliderTextLabel.textAlignment = .center
        sliderTextLabel.isHidden = !showSliderText
        
        sliderHolderView.backgroundColor = defaultSliderBackgroundColor
        sliderHolderView.layer.cornerRadius = sliderCornerRadious
        draggedView.backgroundColor = defaultSlidingColor
        draggedView.layer.cornerRadius = sliderCornerRadious
        draggedView.clipsToBounds = true
        draggedView.layer.masksToBounds = true
    }
    
    private func isTapOnThumbnailViewWithPoint(_ point: CGPoint) -> Bool{
        return self.thumbnailImageView.frame.contains(point)
    }
    
    private func updateThumbnailXPosition(_ x: CGFloat) {
        leadingThumbnailViewConstraint?.constant = x
        setNeedsLayout()
    }
    
    // MARK: UIPanGestureRecognizer
    @objc private func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        if isFinished || !isEnabled {
            return
        }
        let translatedPoint = sender.translation(in: view).x
        switch sender.state {
        case .began:
            break
        case .changed:
            if translatedPoint >= xEndingPoint {
                updateThumbnailXPosition(xEndingPoint)
                return
            }
            if translatedPoint <= thumbnailViewStartingDistance {
                textLabel.alpha = 1
                updateThumbnailXPosition(thumbnailViewStartingDistance)
                return
            }
            updateThumbnailXPosition(translatedPoint)
            textLabel.alpha = (xEndingPoint - translatedPoint) / xEndingPoint
            break
        case .ended:
            if translatedPoint >= xEndingPoint {
                textLabel.alpha = 0
                updateThumbnailXPosition(xEndingPoint)
                // Finish action
                isFinished = true
                delegate?.mtSlideToOpenDelegateDidFinish(self)
                return
            }
            if translatedPoint <= thumbnailViewStartingDistance {
                textLabel.alpha = 1
                updateThumbnailXPosition(thumbnailViewStartingDistance)
                return
            }
            UIView.animate(withDuration: animationVelocity) {
                self.leadingThumbnailViewConstraint?.constant = self.thumbnailViewStartingDistance
                self.textLabel.alpha = 1
                self.layoutIfNeeded()
            }
            break
        default:
            break
        }
    }
    // Others
    public func resetStateWithAnimation(_ animated: Bool) {
        let action = {
            self.leadingThumbnailViewConstraint?.constant = self.thumbnailViewStartingDistance
            self.textLabel.alpha = 1
            self.layoutIfNeeded()
            //
            self.isFinished = false
        }
        if animated {
            UIView.animate(withDuration: animationVelocity) {
                action()
            }
        } else {
            action()
        }
    }
}


class MTRoundImageView: UIImageView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = self.bounds.size.width / 2.0
        self.layer.cornerRadius = radius
    }
}
