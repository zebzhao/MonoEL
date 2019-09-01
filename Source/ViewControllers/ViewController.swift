//
//  ViewController.swift
//  Nebula
//

import UIKit
import RxSwift
import SoundWave
import KDCircularProgress
import RQShineLabel

enum DetectStatus {
    case Verifying
    case Detecting
    case Downloading
}

class ViewController: UIViewController, UICollectionViewDragDelegate, UICollectionViewDropDelegate, RxMediaPickerDelegate
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
    @IBOutlet var wallpaperCollectionViewContainer: UIView!
    @IBOutlet var powerOnIcon: UIImageView!
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var detectView: UIView!
    
    let disposeBag = DisposeBag()
    let recordAudio = RecordAudio()
    let blurEffect = UIBlurEffect(style: .dark)
    let scaleFactor: CGFloat = 3
    
    var audioVisualizationView: AudioVisualizationView!
    var diskCatalog: DiskCatalog!
    var albumImagesDataSource: ImageCellDataSource!
    var wallpaperImagesDataSource: ImageCellDataSource!
    var deleteImagesDataSource: ImageCellDataSource!
    var micIconView: BlurIconView!
    var micOffIconView: BlurIconView!
    var addPhotoIconView: BlurIconView!
    var clearIconView: BlurIconView!
    var deleteIconView: BlurIconView!
    var detectIconView: BlurIconView!
    var progressBar: KDCircularProgress!
    var shineLabel: RQShineLabel!
    
    var currentSongIdSubject = BehaviorSubject<String>(value: "default")
    var wallpaperIndex: Int = 0
    var time: Float = 1
    var queuedText: String?
    var queuedCompletion: (()->Void)!
    var detectStatusClosure: (()->Void)!
    var detectStatus: DetectStatus = .Verifying
    var musicScore: Float = 0
    var stepIndex: Int = 0
    var transitionTime: CGFloat = 0.1
    var transitionTimeDelta: CGFloat = 0.0;
    var resolution = CIVector(x: 0, y: 0)
    
    lazy var mediaPicker: RxMediaPicker =
        {
            return RxMediaPicker(delegate: self)
    }()
    
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
        setUpPhotoView()
        setUpDetectView()
        setUpShineLabel()
        setupCurrentSongIdSubject()
        
        // Default screen
        enterDetectView(detectOn: false)
        animateTextChange("Welcome back, Elyn", completion: nil)
        
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
        transitionTime = fmin(0.95, fmax(0.1, transitionTime + transitionTimeDelta))
        let nb = recordAudio.notesBuffer
        
        let r1 = CIVector(x: CGFloat(nb[0]), y: CGFloat(nb[1]), z: CGFloat(nb[2]), w: CGFloat(nb[3]))
        let r2 = CIVector(x: CGFloat(nb[4]), y: CGFloat(nb[5]), z: CGFloat(nb[6]), w: CGFloat(nb[7]))
        let r3 = CIVector(x: CGFloat(nb[8]), y: CGFloat(nb[9]), z: CGFloat(nb[10]), w: CGFloat(nb[11]))
        
        let args = [time, resolution, r1, r2, r3, transitionTime] as [Any]
        let image = defaultKernel.apply(extent: imageView.bounds, arguments: args)
        
        imageView.image = image
        
        let minBpm = min(90, Int(recordAudio.bpm))
        stepIndex += 1
        
        if 24*stepIndex > minBpm {
            audioVisualizationView.add(meteringLevel: fmax(0.0, fmin(1.0, recordAudio.level/42.0 + 1.0)))
            musicScore = recordAudio.musicScore
            progressBar.angle = min(360.0, Double(musicScore*180.0))
            stepIndex = 0
        }
    }
    
    // MARK:  Delegates
    
    func present(picker: UIImagePickerController) {
        present(picker, animated: true, completion: nil)
    }
    
    func dismiss(picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let item = collectionView === albumCollectionView ? albumImagesDataSource.imageRefs[indexPath.row] : wallpaperImagesDataSource.imageRefs[indexPath.row]
        let itemProvider = NSItemProvider(object: item as ImageRef)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem]
    {
        let item = collectionView === albumCollectionView ? albumImagesDataSource.imageRefs[indexPath.row] : wallpaperImagesDataSource.imageRefs[indexPath.row]
        let itemProvider = NSItemProvider(object: item as ImageRef)
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
        return session.canLoadObjects(ofClass: ImageRef.self)
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
                    var imageRefsCopy = wallpaperImagesDataSource.imageRefs
                    imageRefsCopy.remove(at: sourceIndexPath.row)
                    imageRefsCopy.insert(item.dragItem.localObject as! ImageRef, at: dIndexPath.row)
                    guard diskCatalog.saveWallpaper(name: try! currentSongIdSubject.value(), imageRefs: wallpaperImagesDataSource.imageRefs) else {return}
                    wallpaperImagesDataSource.imageRefs = imageRefsCopy
                } else {
                    var imageRefsCopy = albumImagesDataSource.imageRefs
                    imageRefsCopy.remove(at: sourceIndexPath.row)
                    imageRefsCopy.insert(item.dragItem.localObject as! ImageRef, at: dIndexPath.row)
                    guard diskCatalog.saveAlbum(imageRefs: albumImagesDataSource.imageRefs) else {return}
                    albumImagesDataSource.imageRefs = imageRefsCopy
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
                guard let identifier = item.dragItem.localObject as? ImageRef else {
                    return
                }
                
                if let index = itemSource.imageRefs.firstIndex(of: identifier) {
                    var imageRefsCopy = itemSource.imageRefs
                    let indexPath = IndexPath(row: index, section: 0)
                    imageRefsCopy.remove(at: index)
                    guard (
                        itemSource == albumImagesDataSource &&
                            diskCatalog.deleteImage(relativePath: identifier.path) &&
                            diskCatalog.saveAlbum(imageRefs: imageRefsCopy)) ||
                        (itemSource == wallpaperImagesDataSource &&
                            diskCatalog.saveWallpaper(name: try! currentSongIdSubject.value(), imageRefs: imageRefsCopy))
                        else {return}
                    itemSource.imageRefs = imageRefsCopy
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
                    var imageRefsCopy = wallpaperImagesDataSource.imageRefs
                    imageRefsCopy.insert(item.dragItem.localObject as! ImageRef, at: indexPath.row)
                    guard diskCatalog.saveWallpaper(name: try! currentSongIdSubject.value(), imageRefs: imageRefsCopy) else {continue}
                    wallpaperImagesDataSource.imageRefs = imageRefsCopy
                    indexPaths.append(indexPath)
                } else if collectionView === deleteCollectionView {
                    var imageRefsCopy = albumImagesDataSource.imageRefs
                    imageRefsCopy.remove(at: item.sourceIndexPath!.row)
                    guard diskCatalog.saveAlbum(imageRefs: imageRefsCopy) else {continue}
                    albumImagesDataSource.imageRefs = imageRefsCopy
                } else {
                    var imageRefsCopy = albumImagesDataSource.imageRefs
                    imageRefsCopy.insert(item.dragItem.localObject as! ImageRef, at: indexPath.row)
                    guard diskCatalog.saveAlbum(imageRefs: albumImagesDataSource.imageRefs) else {continue}
                    albumImagesDataSource.imageRefs = imageRefsCopy
                    indexPaths.append(indexPath)
                }
            }
            collectionView.insertItems(at: indexPaths)
        })
    }
    
    // MARK:  Setup
    
    func setUpShineLabel() {
        let labelWidth: CGFloat = detectView.bounds.width - 60
        let labelHeight: CGFloat = 120
        shineLabel = RQShineLabel(frame: CGRect(x: detectView.bounds.midX - labelWidth/2, y: 0.3*detectView.bounds.height - labelHeight, width: labelWidth, height: labelHeight))
        shineLabel.numberOfLines = 2
        shineLabel.backgroundColor = UIColor.clear
        shineLabel.fadeoutDuration = 1.0
        shineLabel.shineDuration = 3.5
        shineLabel.font = UIFont(name: "HelveticaNeue-Light", size: 26.0)
        shineLabel.textAlignment = .center
        view.addSubview(shineLabel)
    }
    
    func setupCurrentSongIdSubject() {
        currentSongIdSubject.subscribe({ (event) in
            let wallpaperRefs = self.diskCatalog.loadWallpaper(name: event.element!) ?? [ImageRef]()
            self.wallpaperIndex = 0
            self.wallpaperImagesDataSource.imageRefs = wallpaperRefs
            self.wallpaperCollectionView.reloadData()
            self.backgroundImageView.animateImageRefs(next: { () -> ImageRef? in
                let imageRefs = self.wallpaperImagesDataSource.imageRefs // Tricky: as this might be reassigned
                let wallpaperIndex = self.wallpaperIndex >= imageRefs.count - 1 ? 0 : self.wallpaperIndex
                let imageRef = imageRefs.indices.contains(wallpaperIndex) ? imageRefs[wallpaperIndex] : nil
                self.wallpaperIndex = wallpaperIndex + 1
                return imageRef
            })
        })
            .disposed(by: disposeBag)
    }
    
    func setUpPhotoView() {
        photoView.alpha = 0
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
        wallpaperCollectionViewContainer.addDashedBorder(color: UIColor.white.withAlphaComponent(0.35))
        
        deleteIconView = BlurIconView(forResource: "delete", x: deleteCollectionView.frame.minX, y: deleteCollectionView.frame.minY)
        deleteIconView.show()
        photoView.addSubview(deleteIconView)
        
        diskCatalog = DiskCatalog(controller: self)
        let albumRefs = diskCatalog.loadAlbum() ?? [ImageRef("WP_Beach"), ImageRef("WP_Coast"), ImageRef("WP_Mountain"), ImageRef("WP_Ocean"), ImageRef("WP_Sakura"), ImageRef("WP_Stars")]
        let wallpaperRefs = diskCatalog.loadWallpaper(name: try! currentSongIdSubject.value()) ?? [ImageRef]()
        albumImagesDataSource = ImageCellDataSource(view: albumCollectionView, imageRefs: albumRefs)
        wallpaperImagesDataSource = ImageCellDataSource(view: wallpaperCollectionView, imageRefs: wallpaperRefs)
        deleteImagesDataSource = ImageCellDataSource(view: deleteCollectionView, imageRefs: [ImageRef]())
    }
    
    func setUpDetectView()
    {
        detectStatusClosure = {
            var text: String
            switch self.detectStatus {
            case .Downloading:
                text = "Downloading the song's lyrics..."
            case .Detecting:
                text = "Detecting what's this song..."
            case .Verifying:
                text = "Listening to what's playing around you..."
            }
            self.animateTextChange(text, completion: self.detectStatusClosure)
        }
        detectIconView = BlurIconView(forResource: "round_mic", x: detectView.bounds.midX - 30, y: 0.45*detectView.bounds.height - 30, pulsing: true)
        detectView.alpha = 0
        let size: CGFloat = 150.0
        audioVisualizationView = AudioVisualizationView(
            frame: CGRect(x: detectView.bounds.midX - size/2,
                          y: 0.45*detectView.bounds.height - size/2,
                          width: size, height: size))
        audioVisualizationView.meteringLevelBarWidth = 5.0
        audioVisualizationView.meteringLevelBarInterItem = 1.0
        audioVisualizationView.meteringLevelBarCornerRadius = 2.0
        audioVisualizationView.audioVisualizationMode = .write
        audioVisualizationView.backgroundColor = UIColor.black.withAlphaComponent(0.6);
        audioVisualizationView.gradientStartColor = UIColor.white.withAlphaComponent(0.9)
        audioVisualizationView.gradientEndColor = UIColor.white.withAlphaComponent(0.6)
        audioVisualizationView.addCircularBorder(color: UIColor.white.withAlphaComponent(0.8), lineWidth: 12)
        audioVisualizationView.layer.mask = createAudioVisualizerGradient()
        let progressSize = size + 20
        progressBar = KDCircularProgress(frame: CGRect(x: detectView.bounds.midX - progressSize/2,
                                                       y: 0.45*detectView.bounds.height - progressSize/2,
                                                       width: progressSize, height: progressSize))
        progressBar.progressThickness = 0.12
        progressBar.trackThickness = 0.0
        progressBar.clockwise = true
        progressBar.gradientRotateSpeed = 2
        progressBar.roundedCorners = false
        progressBar.glowMode = .constant
        progressBar.roundedCorners = true
        progressBar.set(colors: UIColor(rgb: 0x30f5aa), UIColor(rgb: 0x61ebc3), UIColor(rgb: 0x5bedfc), UIColor(rgb: 0xdcf5fd))
        detectIconView.show(activate: true)
        detectIconView.pulse()
        detectView.addSubview(detectIconView)
        detectView.addSubview(audioVisualizationView)
        detectView.addSubview(progressBar)
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
    
    func createAudioVisualizerGradient() -> CAGradientLayer
    {
        let gradient = CAGradientLayer()
        gradient.frame = audioVisualizationView.bounds
        gradient.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor];
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.type = .radial
        return gradient
    }
    
    // MARK:  Transitions
    
    func enterDetectView(detectOn: Bool = false)
    {
        transitionTimeDelta = 0.005
        UIView.animate(withDuration: 0.5) {
            self.detectView.alpha = 1.0
            self.progressBar.alpha = detectOn ? 1.0 : 0.0
            self.detectIconView.effect = detectOn ? self.detectIconView.activeBlurEffect : .none
        }
    }
    
    func exitDetectView()
    {
        transitionTimeDelta = -0.005
        UIView.animate(withDuration: 0.5) {
            self.detectView.alpha = 0.0
        }
    }
    
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
    
    func fadeInSlider()
    {
        UIView.animate(withDuration: 0.15) {
            self.slider.alpha = 1.0
            self.powerOnIcon.alpha = 0.0
        }
    }
    
    func fadeOutSlider(_ showPowerIcon: Bool)
    {
        UIView.animate(withDuration: 0.3) {
            self.slider.alpha = 0.05
            if (showPowerIcon) {
                self.powerOnIcon.alpha = 0.35
            }
        }
    }
    
    func animateTextChange(_ text: String?, completion: (()->Void)?)
    {
        queuedText = text
        queuedCompletion = completion
        if !shineLabel.isShining {
            if shineLabel.isVisible {
                shineLabel.fadeOut {
                    if let qText = self.queuedText {
                        self.shineLabel.text = qText
                        self.shineLabel.shine(completion: self.queuedCompletion)
                        self.queuedText = nil
                    }
                }
            } else {
                if let qText = text {
                    shineLabel.text = qText
                    shineLabel.shine(completion: queuedCompletion)
                }
                queuedText = nil
                queuedCompletion = nil
            }
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
            enterDetectView(detectOn: false)
            fadeOutSlider(true)
            break
        case 0:
            micIconView.show(activate: true)
            detectStatusClosure()
            shineLabel.shine()
            micOffIconView.show()
            addPhotoIconView.hide()
            clearIconView.hide()
            detectLabel.fadeIn(toAlpha: 1)
            cancelLabel.fadeIn(toAlpha: 0.5)
            photosLabel.fadeOut()
            blurOutPhotoView()
            enterDetectView(detectOn: true)
            fadeOutSlider(false)
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
            exitDetectView()
            fadeOutSlider(false)
            break
        default:
            break
        }
    }
    
    @IBAction func sliderTouchDown(_ sender: Any) {
        micIconView.show()
        addPhotoIconView.show()
        fadeInSlider()
        detectLabel.fadeIn(toAlpha: 0.5)
        photosLabel.fadeIn(toAlpha: 0.5)
    }
    
    @IBAction func uploadImageTouchUpInside(_ sender: Any) {
        mediaPicker.selectImage(editable: false)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { arg in
                let (image, _) = arg
                var imageRefsCopy = self.albumImagesDataSource.imageRefs
                let name = DateUtil.nowAsString()
                let indexPath = self.albumCollectionView.indexPathsForVisibleItems[0]
                imageRefsCopy.insert(ImageRef("Images/\(name)"), at: indexPath.row)
                if self.diskCatalog.saveImage(name: name, image: image.fixOrientation()) &&
                    self.diskCatalog.saveAlbum(imageRefs: self.albumImagesDataSource.imageRefs) {
                    self.albumImagesDataSource.imageRefs = imageRefsCopy
                    self.albumCollectionView.insertItems(at: [indexPath])
                }
            }, onError: { error in
                let alertController = UIAlertController(title: "Fail to upload image.", message: error as? String, preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
            }, onCompleted: {
            }, onDisposed: {
            })
            .disposed(by: disposeBag)
    }
}
