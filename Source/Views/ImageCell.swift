//
//  DraggableCollectionView.swift
//  Nebula
//
//  Created by Zeb Zhao on 7/23/19.
//

import UIKit

class ImageCellDataSource: NSObject, UICollectionViewDataSource {
    var imagePaths: [String]
    var view: UICollectionView
    
    init(view: UICollectionView, imagePaths: [String]) {
        self.view = view
        self.imagePaths = imagePaths
        super.init()
        view.dataSource = self
        view.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
    }
    
    @objc func removeBtnClick(_ sender: UIButton)   {
        let hitPoint = sender.convert(CGPoint(x: sender.frame.width, y: sender.frame.height), to: view)
        let hitIndex = view.indexPathForItem(at: hitPoint)
        self.imagePaths.remove(at: (hitIndex!.row))
        view.reloadData()
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imagePaths.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell
        cell.imgView.image = UIImage(named: "\(imagePaths[indexPath.row])")
        return cell
    }
}

class ImageCell : UICollectionViewCell
{
    static let identifier = "ImageCell"
    
    var imgView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clear
        
        imgView = UIImageView(frame: self.contentView.bounds)
        imgView.contentMode = .scaleAspectFill
        imgView.layer.cornerRadius = 8
        imgView.clipsToBounds = true
        
        contentView.addSubview(imgView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
