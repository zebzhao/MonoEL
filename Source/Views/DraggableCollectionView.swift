//
//  DraggableCollectionView.swift
//  Nebula
//
//  Created by Zeb Zhao on 7/23/19.
//

import UIKit

class DraggableCollectionViewDataSource: NSObject, UICollectionViewDataSource {
    var imagePaths: [String]
    var view: DraggableCollectionView
    
    init(view: DraggableCollectionView, imagePaths: [String]) {
        self.view = view
        self.imagePaths = imagePaths
        super.init()
        view.dataSource = self
    }
    
    @objc func removeBtnClick(_ sender: UIButton)   {
        let hitPoint = sender.convert(CGPoint.zero, to: view)
        let hitIndex = view.indexPathForItem(at: hitPoint)
        self.imagePaths.remove(at: (hitIndex?.row)!)
        view.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imagePaths.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let draggableCollectionView = collectionView as! DraggableCollectionView
        let tmp = imagePaths[sourceIndexPath.item]
        imagePaths[sourceIndexPath.item] = imagePaths[destinationIndexPath.item]
        imagePaths[destinationIndexPath.item] = tmp
        draggableCollectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let draggableCollectionView = collectionView as! DraggableCollectionView
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SmallImgCell.identifier, for: indexPath) as! SmallImgCell
        cell.backgroundColor = UIColor.clear
        cell.imgView.image = UIImage(named: "\(imagePaths[indexPath.row])")
        cell.removeBtn.addTarget(self, action: #selector(removeBtnClick(_:)), for: .touchUpInside)
        
        if draggableCollectionView.longPressedEnabled   {
            cell.startAnimate()
        } else{
            cell.stopAnimate()
        }
        
        return cell
    }
}

class SmallImgCell : UICollectionViewCell
{
    static let identifier = "SmallImgCell"
    
    var imgView: UIImageView!
    var removeBtn: UIButton!

    var isAnimate: Bool! = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imgView = UIImageView(frame: self.contentView.bounds)
        imgView.contentMode = .scaleAspectFill
        imgView.layer.cornerRadius = 8
        imgView.clipsToBounds = true
        removeBtn = UIButton(frame: CGRect(x: -12, y: -12, width: 24, height: 24))
        removeBtn.setImage(UIImage(named: "RemoveIcon"), for: .normal)
        removeBtn.tintColor = UIColor.groupTableViewBackground
        
        contentView.addSubview(imgView)
        addSubview(removeBtn)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //Animation of image
    func startAnimate() {
        let shakeAnimation = CABasicAnimation(keyPath: "transform.rotation")
        shakeAnimation.duration = 0.05
        shakeAnimation.repeatCount = 4
        shakeAnimation.autoreverses = true
        shakeAnimation.duration = 0.2
        shakeAnimation.repeatCount = Float.infinity
        
        let startAngle: Float = (-2) * 3.14159/180
        let stopAngle = -startAngle
        
        shakeAnimation.fromValue = NSNumber(value: startAngle as Float)
        shakeAnimation.toValue = NSNumber(value: 3 * stopAngle as Float)
        shakeAnimation.autoreverses = true
        shakeAnimation.timeOffset = 290 * drand48()
        
        let layer: CALayer = self.layer
        layer.add(shakeAnimation, forKey:"animate")
        removeBtn.isHidden = false
        isAnimate = true
    }
    
    func stopAnimate() {
        let layer: CALayer = self.layer
        layer.removeAnimation(forKey: "animate")
        self.removeBtn.isHidden = true
        isAnimate = false
    }
}

class DraggableCollectionView: UICollectionView
{
    var longPressedEnabled = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        register(SmallImgCell.self, forCellWithReuseIdentifier: SmallImgCell.identifier)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longTap(_:)))
        self.addGestureRecognizer(longPressGesture)
    }
    
    @objc func longTap(_ gesture: UIGestureRecognizer){
        switch(gesture.state) {
        case .began:
            guard let selectedIndexPath = self.indexPathForItem(at: gesture.location(in: self)) else {
                return
            }
            self.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            self.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            self.endInteractiveMovement()
//            doneBtn.isHidden = false
            longPressedEnabled = true
            self.reloadData()
        default:
            self.cancelInteractiveMovement()
        }
    }
}
