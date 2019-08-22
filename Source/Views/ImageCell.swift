//
//  DraggableCollectionView.swift
//  Nebula
//
//  Created by Zeb Zhao on 7/23/19.
//

import UIKit

class ImageCellDataSource: NSObject, UICollectionViewDataSource {
    var imageRefs: [ImageRef]
    var view: UICollectionView
    
    init(view: UICollectionView, imageRefs: [ImageRef]) {
        self.view = view
        self.imageRefs = imageRefs
        super.init()
        view.dataSource = self
        view.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.identifier)
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageRefs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.identifier, for: indexPath) as! ImageCell
        cell.imgView.image = UIImage.loadImageRef(imageRef: imageRefs[indexPath.row])
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
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        
        contentView.addSubview(imgView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
