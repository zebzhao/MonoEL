//
//  ViewController.swift
//  Nebula
//
//  Created by Simon Gladman on 08/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UICollectionViewDragDelegate, UICollectionViewDropDelegate
{
    @IBOutlet var imageViewContainer: UIView!
    @IBOutlet var imageView: MetalImageView!
    @IBOutlet var slider: VSSlider!
    @IBOutlet var detectLabel: UILabel!
    @IBOutlet var photosLabel: UILabel!
    @IBOutlet var cancelLabel: UILabel!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var albumCollectionView: UICollectionView!
    @IBOutlet var albumCollectionViewContainer: UIView!
    @IBOutlet var deleteCollectionView: UICollectionView!
    @IBOutlet var photoView: UIView!
    @IBOutlet var wallpaperCollectionView: UICollectionView!
    
    let recordAudio = RecordAudio()
    let blurEffect = UIBlurEffect(style: .dark)
    let scaleFactor: CGFloat = 3
    
    var albumImagesDataSource: ImageCellDataSource!
    var wallpaperImagesDataSource: ImageCellDataSource!
    var deleteImagesDataSource: ImageCellDataSource!
    var micIconView: BlurIconView!
    var micOffIconView: BlurIconView!
    var addPhotoIconView: BlurIconView!
    var clearIconView: BlurIconView!
    var deleteIconView: BlurIconView!
    
    var time: Float = 1
    var resolution = CIVector(x: 0, y: 0)
    
    lazy var defaultKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "mainImage", fromMetalLibraryData: data)
            return kernel
    }()
    
    // MARK:  Overrides
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        setUpSlider()
        setUpAlbum()
        
        photoView.alpha = 0
        blurView.effect = nil
        imageViewContainer.transform = CGAffineTransform.identity.scaledBy(x: scaleFactor, y: scaleFactor)

        let displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        
        recordAudio.startRecording()
    }
    
    override func viewDidLayoutSubviews()
    {
        imageViewContainer.bounds = CGRect.init(x: 0.0, y: 0.0, width: ceil(view.bounds.width/scaleFactor), height: ceil(view.bounds.height/scaleFactor))
        imageViewContainer.frame = CGRect.init(x: 0.0, y: 0.0, width: view.bounds.width, height: view.bounds.height)
        resolution = CIVector(x: imageViewContainer.bounds.width, y: imageViewContainer.bounds.height)
    }
    
    // MARK: Step
    
    @objc func step()
    {
        time += 0.0001*recordAudio.bpm + 0.005
        let nb = recordAudio.notesBuffer
        
        let r1 = CIVector(x: CGFloat(nb[0]), y: CGFloat(nb[1]), z: CGFloat(nb[2]), w: CGFloat(nb[3]))
        let r2 = CIVector(x: CGFloat(nb[4]), y: CGFloat(nb[5]), z: CGFloat(nb[6]), w: CGFloat(nb[7]))
        let r3 = CIVector(x: CGFloat(nb[8]), y: CGFloat(nb[9]), z: CGFloat(nb[10]), w: CGFloat(nb[11]))
        
        let args = [time, resolution, r1, r2, r3] as [Any]
        let image = defaultKernel.apply(extent: imageView.bounds, arguments: args)
        
        imageView.image = image
    }
    
    // MARK:  Delegates
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = collectionView === albumCollectionView ? albumImagesDataSource.imagePaths[indexPath.row] : wallpaperImagesDataSource.imagePaths[indexPath.row]
        let itemProvider = NSItemProvider(object: item as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem]
    {
        let item = collectionView === albumCollectionView ? albumImagesDataSource.imagePaths[indexPath.row] : wallpaperImagesDataSource.imagePaths[indexPath.row]
        let itemProvider = NSItemProvider(object: item as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters?
    {
        let previewParameters = UIDragPreviewParameters()
        previewParameters.backgroundColor = UIColor.clear
        return previewParameters
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool
    {
        return session.canLoadObjects(ofClass: NSString.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
    {
        if collectionView === albumCollectionView {
            if collectionView.hasActiveDrag {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            } else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        } else if collectionView === deleteCollectionView {
            if collectionView.hasActiveDrag {
                return UICollectionViewDropProposal(operation: .forbidden)
            } else {
                return UICollectionViewDropProposal(operation: .move, intent: .unspecified)
            }
        } else {
            if collectionView.hasActiveDrag {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            } else {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
    {
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            // Get last index path of table view.
            let section = collectionView.numberOfSections - 1
            let row = collectionView.numberOfItems(inSection: section)
            destinationIndexPath = IndexPath(row: row, section: section)
        }
        
        switch coordinator.proposal.operation {
        case .move:
            if coordinator.proposal.intent == .insertAtDestinationIndexPath{
                self.reorderItems(coordinator: coordinator, destinationIndexPath:destinationIndexPath, collectionView: collectionView)
            } else {
                self.removeItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
            }
        case .copy:
            self.copyItems(coordinator: coordinator, destinationIndexPath: destinationIndexPath, collectionView: collectionView)
        default:
            return
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnter session: UIDropSession) {
        if collectionView === deleteCollectionView {
            deleteIconView.show(activate: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        if collectionView === deleteCollectionView {
            deleteIconView.show(activate: false)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        if collectionView === deleteCollectionView {
            deleteIconView.show(activate: false)
        }
    }
    
    private func reorderItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView)
    {
        let items = coordinator.items
        if items.count == 1, let item = items.first, let sourceIndexPath = item.sourceIndexPath
        {
            var dIndexPath = destinationIndexPath
            if dIndexPath.row >= collectionView.numberOfItems(inSection: 0)
            {
                dIndexPath.row = collectionView.numberOfItems(inSection: 0) - 1
            }
            collectionView.performBatchUpdates({
                if collectionView === wallpaperCollectionView {
                    wallpaperImagesDataSource.imagePaths.remove(at: sourceIndexPath.row)
                    wallpaperImagesDataSource.imagePaths.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
                } else {
                    albumImagesDataSource.imagePaths.remove(at: sourceIndexPath.row)
                    albumImagesDataSource.imagePaths.insert(item.dragItem.localObject as! String, at: dIndexPath.row)
                }
                collectionView.deleteItems(at: [sourceIndexPath])
                collectionView.insertItems(at: [dIndexPath])
            })
            coordinator.drop(items.first!.dragItem, toItemAt: dIndexPath)
        }
    }
    
    private func removeItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView)
    {
        collectionView.performBatchUpdates({
            var itemSource: ImageCellDataSource!
            var itemSourceView: UICollectionView!
            
            if albumCollectionView.hasActiveDrag {
                itemSource = albumImagesDataSource
                itemSourceView = albumCollectionView
            }
            else if wallpaperCollectionView.hasActiveDrag {
                itemSource = wallpaperImagesDataSource
                itemSourceView = wallpaperCollectionView
            }
            else {
                return
            }
            
            for item in coordinator.items
            {
                guard let identifier = item.dragItem.localObject as? String else {
                    return
                }
                
                if let index = itemSource.imagePaths.firstIndex(of: identifier) {
                    let indexPath = IndexPath(row: index, section: 0)
                    itemSource.imagePaths.remove(at: index)
                    itemSourceView.deleteItems(at: [indexPath])
                }
            }
        })
    }
    
    private func copyItems(coordinator: UICollectionViewDropCoordinator, destinationIndexPath: IndexPath, collectionView: UICollectionView)
    {
        collectionView.performBatchUpdates({
            var indexPaths = [IndexPath]()
            for (index, item) in coordinator.items.enumerated()
            {
                let indexPath = IndexPath(row: destinationIndexPath.row + index, section: destinationIndexPath.section)
                if collectionView === wallpaperCollectionView {
                    wallpaperImagesDataSource.imagePaths.insert(item.dragItem.localObject as! String, at: indexPath.row)
                    indexPaths.append(indexPath)
                } else if collectionView === deleteCollectionView {
                    albumImagesDataSource.imagePaths.remove(at: item.sourceIndexPath!.row)
                } else {
                    albumImagesDataSource.imagePaths.insert(item.dragItem.localObject as! String, at: indexPath.row)
                    indexPaths.append(indexPath)
                }
            }
            collectionView.insertItems(at: indexPaths)
        })
    }
    
    // MARK:  Setup
    
    func setUpAlbum() {
        albumCollectionView.dragInteractionEnabled = true
        albumCollectionView.dragDelegate = self
        albumCollectionView.dropDelegate = self
        albumCollectionViewContainer.layer.mask = createAlbumViewGradient()
        deleteCollectionView.dragInteractionEnabled = true
        deleteCollectionView.dropDelegate = self
        wallpaperCollectionView.dragInteractionEnabled = true
        wallpaperCollectionView.dragDelegate = self
        wallpaperCollectionView.dropDelegate = self
        wallpaperCollectionView.reorderingCadence = .fast
        wallpaperCollectionView.addDashedBorder(color: UIColor.white.withAlphaComponent(0.3))
        
        deleteIconView = BlurIconView(forResource: "delete", x: deleteCollectionView.frame.minX, y: deleteCollectionView.frame.minY)
        deleteIconView.show()
        photoView.addSubview(deleteIconView)
        
        albumImagesDataSource = ImageCellDataSource(view: albumCollectionView, imagePaths: ["Image", "Image", "Image", "Image", "Image", "Image", "Image", "Image"])
        wallpaperImagesDataSource = ImageCellDataSource(view: wallpaperCollectionView, imagePaths: [String]())
        deleteImagesDataSource = ImageCellDataSource(view: deleteCollectionView, imagePaths: [String]())
    }
    
    func setUpSlider()
    {
        let x = slider.frame.minX
        let midX = slider.frame.midX - 36
        let maxX = slider.frame.maxX - 76
        let y = slider.frame.minY
        micIconView = BlurIconView(forResource: "mic", x: x, y: y)
        micOffIconView = BlurIconView(forResource: "mic_off", x: midX, y: y)
        addPhotoIconView = BlurIconView(forResource: "add_photo", x: maxX, y: y)
        clearIconView = BlurIconView(forResource: "clear", x: midX, y: y)
        view.addSubview(micIconView)
        view.addSubview(micOffIconView)
        view.addSubview(addPhotoIconView)
        view.addSubview(clearIconView)
        view.bringSubviewToFront(slider)
    }
    
    func createAlbumViewGradient() -> CAGradientLayer
    {
        let bounds = albumCollectionViewContainer.bounds
        let invertedBoundHeight = 1/bounds.height
        let locations = [35.0*invertedBoundHeight, 80.0*invertedBoundHeight, 1.0 - 80.0*invertedBoundHeight, 1.0 - 35.0*invertedBoundHeight] as [NSNumber]
        let gradient = CAGradientLayer()
        gradient.frame = bounds;
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor];
        gradient.locations = locations
        return gradient
    }
    
    // MARK:  Transitions
    
    func blurOutPhotoView()
    {
        guard self.blurView?.effect != nil else {return}
        UIView.animate(withDuration: 0.5) {
            self.photoView.alpha = 0.0
            self.blurView.effect = nil
        }
    }
    
    func blurInPhotoView()
    {
        guard self.blurView?.effect == nil else {return}
        UIView.animate(withDuration: 0.5) {
            self.photoView.alpha = 1.0
            self.blurView.effect = self.blurEffect
        }
    }
    
    // MARK:  Actions
    
    @IBAction func sliderValueChanged(_ sender: Any) {
        switch(slider.roundedValue) {
        case 1.0:
            micIconView.hide()
            micOffIconView.hide()
            addPhotoIconView.hide()
            clearIconView.hide()
            detectLabel.fadeOut()
            photosLabel.fadeOut()
            cancelLabel.fadeOut()
            blurOutPhotoView()
            break
        case 0:
            micIconView.show(activate: true)
            micOffIconView.show()
            addPhotoIconView.hide()
            clearIconView.hide()
            detectLabel.fadeIn(toAlpha: 1)
            cancelLabel.fadeIn(toAlpha: 0.5)
            photosLabel.fadeOut()
            blurOutPhotoView()
            break
        case 2.0:
            micIconView.hide()
            micOffIconView.hide()
            addPhotoIconView.show(activate: true)
            clearIconView.show()
            photosLabel.fadeIn(toAlpha: 1)
            cancelLabel.fadeIn(toAlpha: 0.5)
            detectLabel.fadeOut()
            blurInPhotoView()
            break
        default:
            break
        }
    }
    
    @IBAction func sliderTouchDown(_ sender: Any) {
        micIconView.show()
        addPhotoIconView.show()
        detectLabel.fadeIn(toAlpha: 0.5)
        photosLabel.fadeIn(toAlpha: 0.5)
    }
}
