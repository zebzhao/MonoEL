//
//  ViewController.swift
//  Nebula
//

import UIKit
import RxSwift
import KDCircularProgress
import RQShineLabel
import MediaPlayer

enum DetectStatus {
    case Stopped
    case Verifying
    case Detecting
    case Downloading
}

class Song {
    let title: String?
    let artist: String?
    let duration: Int?
    let lyrics: String?
    
    var id: String {
        get {
            return "\(artist ?? "") ~ \(title ?? "") ~ \(duration ?? 0)"
        }
    }
    
    var display: String {
        get {
            return "\(title ?? "")\(artist != nil ? " ⁓ " : "")\(artist ?? "")"
        }
    }
    
    init(title: String?, artist: String?, duration: Int?, lyrics: String?) {
        self.title = title
        self.artist = artist
        self.duration = duration
        self.lyrics = lyrics
    }
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
    @IBOutlet var lyricsView: UIView!
    @IBOutlet var songTitleLabel: RQShineLabel!
    @IBOutlet var scrollingLyricsView: LyricsView!
    @IBOutlet var scrollingLyricsViewContainer: UIView!
    
    let disposeBag = DisposeBag()
    let recordAudio = RecordAudio()
    let lrcDownloader = LrcDownloader([MiguSource(), NetEaseSource(), GecimiSource(), GecimiRelaxSource()])
    let greeting1 = ["嗨! 動動", "Hi⁓", "嘿⁓", "Selamat pagi!", "Hey, hey, beautiful!", "Heya!", "嘿嘿, 美丽的", "Yo, over here!", "Hola⁓", "你好!", "Aloha Kakahiaka!"]
    let greeting2 = ["Sing a song!", "Say something...", "Sounding perfect!", "好久不见!", "Welcome back!", "Play with me!", "Missed you angel⁓", "Looking beautiful as always!", "好聽, 好聽!",
        "Long time no see!", "Play me a song!", "Gimme some music!", "發一首歌 DJ!", "來一首歌!"]
    let defaultAlbumRefList = [ImageRef("WP_Beach"), ImageRef("WP_Road"), ImageRef("WP_Coast"), ImageRef("WP_Mountain"), ImageRef("WP_Ocean"), ImageRef("WP_Balloons"), ImageRef("WP_Dawn"), ImageRef("WP_Stars"), ImageRef("WP_Waves")]
    let player = MPMusicPlayerController.systemMusicPlayer
    let blurEffect = UIBlurEffect(style: .dark)
    let scaleFactor: CGFloat = 3
    let paragraphStyle = NSMutableParagraphStyle()
    
    var audioVisualizationView: SwiftSiriWaveformView!
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
    var shineLabel: ShineLabel!
    
    var currentSongSubject = BehaviorSubject<Song?>(value: nil)
    var wallpaperIndex: Int = 0
    var time: Float = 1
    var queuedText: String?
    var queuedCompletion: (()->Void)!
    var detectStatusClosure: (()->Void)!
    var detectStatus: DetectStatus = .Stopped
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
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 12
        
        setUpSlider()
        setUpPhotoView()
        setUpDetectView()
        setUpShineLabel()
        setupCurrentSongSubject()
        setupMusicPlayer()
        setupLyricsView()
        
        // Default screen
        enterDetectView(detectOn: false)
        animateTextChange(greeting1.randomElement()) {
            self.animateTextChange(self.greeting2.randomElement(), completion: {
                self.fadeOutText(duration: 1.5, delay: 2.5)
                //self.syncNowPlayingItem()
            })
        }
        
        blurView.effect = nil
        imageViewContainer.transform = CGAffineTransform.identity.scaledBy(x: scaleFactor, y: scaleFactor)
        
        let displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        
        recordAudio.startRecording()
        
        currentSongSubject.onNext(Song(title: "Test 12345 Test 12345 Test 12345", artist: "Test", duration: 200, lyrics: """
                    [ti:爱情之所以为爱情]
                    [ar:梁静茹]
                    [al:静茹&情歌 别再为他流泪]
                    [by:william王子]
                    [01:51.33][00:02.30]梁静茹-爱情之所以为爱情
                    [01:59.15][00:08.66]作词:黄婷 作曲:周谷淳
                    [00:13.92]编曲：史卡非
                    [01:46.52]专辑：静茹&情歌 别再为他流泪
                    [00:16.63]
                    [00:18.81]买CD
                    [00:19.44]把你的声音丢在角落
                    [00:22.92]看电影
                    [00:23.91]到结局总是配角的错
                    [00:27.98]你要的故事 让你去说
                    [00:32.44]我要的生活 我好好过
                    [00:35.68]
                    [00:36.12]写日记
                    [00:37.41]写不出是谁的感受
                    [00:40.60]夜空里
                    [00:41.69]每个人占有一个星座
                    [00:45.07]你到底懂不懂
                    [00:48.50]我只要一点温热的触碰
                    [00:53.84]
                    [00:56.12]你到底懂不懂
                    [00:59.63]有些话 并不是
                    [01:01.99]一定要说
                    [01:04.67]
                    [01:08.08]你总说爱情之所以为爱情
                    [01:10.89]是用来挥霍
                    [01:12.81]你总是漫不在乎
                    [01:14.77]当我看著自己的稀薄
                    [01:17.61]你编织的感觉难以捉摸
                    [01:21.86]你比我的梦境还困惑
                    [01:25.59]
                    [01:25.98]我看见爱情之所以为爱情
                    [01:28.77]谁都在挥霍
                    [01:30.55]我想的天长地久
                    [01:32.55]也许只是时间的荒谬
                    [01:35.33]我沉迷的感动与你不同
                    [01:39.54]我的了解让我自由
                    [02:06.26][01:56.74][01:44.14]
                    [02:17.50]一场雨
                    [02:18.62]有时候下得不是时候
                    [02:21.92]就像你
                    [02:23.13]说难过不是真的难过
                    [02:26.26]你到底懂不懂
                    [02:29.61]我只要一个安稳的等候
                    [02:34.64]
                    [02:37.42]你到底懂不懂
                    [02:40.69]想你想得好像
                    [02:43.50]空气都停了
                    [02:47.87]
                    [02:49.32]你总说爱情之所以为爱情
                    [02:52.03]是用来挥霍
                    [02:53.82]你总是漫不在乎
                    [02:55.96]当我看著自己的稀薄
                    [02:58.69]你编织的感觉难以捉摸
                    [03:03.00]你比我的梦境还困惑
                    [03:06.57]
                    [03:06.88]我看见爱情之所以为爱情
                    [03:09.79]谁都在挥霍
                    [03:12.07]我想的天长地久
                    [03:13.76]也许只是时间的荒谬
                    [03:16.44]我沉迷的感动 与你不同
                    [03:20.74]我的了解让我自由
                    [03:24.67]你总说爱情之所以为爱情
                    [03:27.54]是用来挥霍
                    [03:29.41]你总是漫不在乎
                    [03:31.39]当我看著自己的稀薄
                    [03:34.54]你编织的感觉难以捉摸
                    [03:38.67]你比我的梦境还困惑
                    [03:41.91]
                    [03:42.32]我看见爱情之所以为爱情
                    [03:45.35]谁都在挥霍
                    [03:47.20]我想的天长地久
                    [03:49.23]也许只是时间的荒谬
                    [03:51.92]我沉迷的感动 与你不同
                    [03:56.39]我的了解让我自由
                    [04:00.98]我沉迷的感动 与你不同
                    [04:06.91]我的了解让我自由
                    [04:12.30]

                    """))
    }
    
    override func viewDidLayoutSubviews()
    {
        imageViewContainer.bounds = CGRect.init(x: 0.0, y: 0.0, width: ceil(view.bounds.width/scaleFactor), height: ceil(view.bounds.height/scaleFactor))
        imageViewContainer.frame = CGRect.init(x: 0.0, y: 0.0, width: view.bounds.width, height: view.bounds.height)
        resolution = CIVector(x: imageViewContainer.bounds.width, y: imageViewContainer.bounds.height)
    }
    
    // MARK:  Step
    
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

        audioVisualizationView.amplitude = max(audioVisualizationView.amplitude*0.985, CGFloat(fmax(0.0, fmin(1.0, recordAudio.level/36.0 + 1.0))))
    }
    
    // MARK:  Observers
    
    private func updateNowPlayingItem() {
        if let nowPlayingItem = player.nowPlayingItem, let title = nowPlayingItem.title {
            let durationInMs = Int(nowPlayingItem.playbackDuration*1000)
            if let candidate = diskCatalog.loadCandidate(song: title, singer: nowPlayingItem.artist, durationInMs: durationInMs) {
                self.currentSongSubject.onNext(Song(title: candidate.song, artist: candidate.singer, duration: candidate.duration, lyrics: candidate.lyrics))
            } else {
                lrcDownloader.getLyrics(song: title, singer: nowPlayingItem.artist, durationInMs: durationInMs, complete: { (candidate) in
                    if let can=candidate {
                        self.currentSongSubject.onNext(Song(title: can.song, artist: can.singer, duration: can.duration, lyrics: can.lyrics))
                        if can.lyrics != nil {
                            self.diskCatalog.saveCandidate(song: title, singer: nowPlayingItem.artist, durationInMs: durationInMs, candidate: can)
                        }
                    } else {
                        self.currentSongSubject.onNext(nil)
                    }
                })
            }
        }
    }
    
    func syncNowPlayingItem() {
        switch player.playbackState {
        case .paused:
            scrollingLyricsView.timer.pause()
        case .playing:
            if let songTitle = try? currentSongSubject.value()?.title,
                let nowPlayingItemTitle = player.nowPlayingItem?.title {
                print("playing", songTitle, nowPlayingItemTitle, songTitle == nowPlayingItemTitle)
                if songTitle != nowPlayingItemTitle {
                    updateNowPlayingItem()
                }
            }
            scrollingLyricsView.timer.seek(toTime: player.currentPlaybackTime)
            scrollingLyricsView.timer.play()
        case .seekingBackward:
            scrollingLyricsView.timer.seek(toTime: player.currentPlaybackTime)
        case .seekingForward:
            scrollingLyricsView.timer.seek(toTime: player.currentPlaybackTime)
        case .stopped:
            scrollingLyricsView.timer.pause()
            scrollingLyricsView.timer.seek(toTime: 0)
        case .interrupted:
            scrollingLyricsView.timer.pause()
            scrollingLyricsView.timer.seek(toTime: 0)
        @unknown default:
            scrollingLyricsView.timer.pause()
        }
    }
    
    @objc private func nowPlayingItemIsChanged(notification: NSNotification){
        syncNowPlayingItem()
    }
    
    @objc private func playbackStateIsChanged(notification: NSNotification){
        syncNowPlayingItem()
    }
    
    // MARK:  Delegates
    
    deinit {
        player.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
    }
    
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
                    let songId = (try? currentSongSubject.value()?.id) ?? "default"
                    guard diskCatalog.saveWallpaper(name: songId, imageRefs: wallpaperImagesDataSource.imageRefs) else {return}
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
                    let songId = (try? currentSongSubject.value()?.id) ?? "default"
                    imageRefsCopy.remove(at: index)
                    guard (
                        itemSource == albumImagesDataSource &&
                            diskCatalog.deleteImage(relativePath: identifier.path) &&
                            diskCatalog.saveAlbum(imageRefs: imageRefsCopy)) ||
                        (itemSource == wallpaperImagesDataSource &&
                            diskCatalog.saveWallpaper(name: songId, imageRefs: imageRefsCopy))
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
                    let songId = (try? currentSongSubject.value()?.id) ?? "default"
                    guard diskCatalog.saveWallpaper(name: songId, imageRefs: imageRefsCopy) else {continue}
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
    
    func setupMusicPlayer() {
        player.beginGeneratingPlaybackNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.nowPlayingItemIsChanged(notification:)),
            name: NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.playbackStateIsChanged(notification:)),
            name: NSNotification.Name.MPMusicPlayerControllerPlaybackStateDidChange,
            object: nil)
    }
    
    func setUpShineLabel() {
        let labelWidth: CGFloat = detectView.bounds.width - 60
        let labelHeight: CGFloat = 120
        shineLabel = ShineLabel(frame: CGRect(x: detectView.bounds.midX - labelWidth/2, y: 0.3*detectView.bounds.height - labelHeight, width: labelWidth, height: labelHeight))
        shineLabel.numberOfLines = 2
        shineLabel.backgroundColor = UIColor.clear
        shineLabel.fadeoutDuration = 1.0
        shineLabel.shineDuration = 3.5
        shineLabel.font = UIFont(name: "HelveticaNeue-Light", size: 26.0)
        shineLabel.textAlignment = .center
        view.insertSubview(shineLabel, belowSubview: blurView)
    }
    
    func setupCurrentSongSubject() {
        currentSongSubject.subscribe({ (event) in
            let songId = event.element??.id ?? "default"
            let wallpaperRefs = self.loadWallpaperRefs(songId: songId)
            self.wallpaperIndex = 0
            self.wallpaperImagesDataSource.imageRefs = wallpaperRefs
            self.wallpaperCollectionView.reloadData()
            self.songTitleLabel.attributedText = NSAttributedString(string: event.element??.display ?? "", attributes: [.paragraphStyle : self.paragraphStyle])
            self.songTitleLabel.shine()
            self.scrollingLyricsView.lyrics = event.element??.lyrics
            self.backgroundImageView.animateImageRefs(next: { () -> ImageRef? in
                let imageRefs = self.wallpaperImagesDataSource.imageRefs // Tricky: as this might be reassigned
                let wallpaperIndex = self.wallpaperIndex >= imageRefs.count ? 0 : self.wallpaperIndex
                let imageRef = imageRefs.indices.contains(wallpaperIndex) ? imageRefs[wallpaperIndex] : nil
                self.wallpaperIndex = wallpaperIndex + 1
                return imageRef
            })
            self.scrollingLyricsView.timer.play()
            self.enterHomeScreen()
        })
            .disposed(by: disposeBag)
    }
    
    func setupLyricsView() {
        songTitleLabel.numberOfLines = 2
        songTitleLabel.backgroundColor = UIColor.clear
        songTitleLabel.fadeoutDuration = 1.0
        songTitleLabel.shineDuration = 2.5
        songTitleLabel.font = UIFont(name: "HelveticaNeue-Light", size: 26.0)
        songTitleLabel.textAlignment = .left
        scrollingLyricsView.lyricFont = UIFont.systemFont(ofSize: 25)
        scrollingLyricsView.lyricTextColor = UIColor.white.withAlphaComponent(0.777)
        scrollingLyricsView.lyricHighlightedFont = UIFont.systemFont(ofSize: 25)
        scrollingLyricsView.lyricHighlightedTextColor = UIColor.white
        scrollingLyricsView.backgroundColor = UIColor.clear
        scrollingLyricsView.lineSpacing = 25
        scrollingLyricsViewContainer.layer.mask = createScrollingLyricViewGradient()
    }
    
    func setUpPhotoView() {
        photoView.alpha = 0.0
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
        deleteImagesDataSource = ImageCellDataSource(view: deleteCollectionView, imageRefs: [ImageRef]())
        let albumRefs = diskCatalog.loadAlbum() ?? defaultAlbumRefList
        albumImagesDataSource = ImageCellDataSource(view: albumCollectionView, imageRefs: albumRefs)
        let songId = (try? currentSongSubject.value()?.id) ?? "default"
        self.loadWallpaperRefs(songId: songId)
    }
    
    func setUpDetectView()
    {
        detectStatusClosure = {
            var text: String?
            switch self.detectStatus {
            case .Downloading:
                text = "Downloading the song's lyrics..."
            case .Detecting:
                text = "Detecting what's this song..."
            case .Verifying:
                text = "Listening to what's playing around you..."
            case .Stopped:
                text = nil
            }
            if text == nil {
                self.fadeOutText()
            } else {
                self.animateTextChange(text, completion: self.detectStatusClosure)
            }
        }
        detectIconView = BlurIconView(forResource: "round_mic", x: detectView.bounds.midX - 30, y: 0.45*detectView.bounds.height - 30, pulsing: true)
        detectView.alpha = 0
        let size: CGFloat = 150.0
        audioVisualizationView = SwiftSiriWaveformView(
            frame: CGRect(x: detectView.bounds.midX - size/2,
                          y: 0.45*detectView.bounds.height - size/2,
                          width: size, height: size))
        audioVisualizationView.amplitude = 0.0
        audioVisualizationView.backgroundColor = UIColor.black.withAlphaComponent(0.6);
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
        let invertedBoundHeight = Float(1/bounds.height)
        let locations = [NSNumber(value: 35.0*invertedBoundHeight),
                         NSNumber(value: 80.0*invertedBoundHeight),
                         NSNumber(value: 1.0 - 80.0*invertedBoundHeight),
                         NSNumber(value: 1.0 - 35.0*invertedBoundHeight)]
        let gradient = CAGradientLayer()
        gradient.frame = bounds;
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor];
        gradient.locations = locations
        return gradient
    }
    
    func createScrollingLyricViewGradient() -> CAGradientLayer
    {
        let bounds = scrollingLyricsView.bounds
        let invertedBoundHeight = Float(1/bounds.height)
        let locations = [NSNumber(value: 35.0*invertedBoundHeight),
                         NSNumber(value: 80.0*invertedBoundHeight),
                         NSNumber(value: 1.0 - 80.0*invertedBoundHeight),
                         NSNumber(value: 1.0 - 35.0*invertedBoundHeight)]
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
    
    func enterLyricView()
    {
        UIView.animate(withDuration: 0.5) {
            self.shineLabel.alpha = 0.0
            self.lyricsView.alpha = 1.0
        }
    }
    
    func exitLyricView()
    {
        UIView.animate(withDuration: 0.5) {
            self.lyricsView.alpha = 0.0
        }
    }
    
    func enterHomeScreen()
    {
        let songId = (try? currentSongSubject.value()?.id) ?? "default"
        if songId == "default" {
            enterDetectView(detectOn: false)
        } else {
            exitDetectView()
            enterLyricView()
        }
    }
    
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
                self.powerOnIcon.alpha = 0.2
            }
        }
    }
    
    func fadeOutText(duration: TimeInterval = 0.5, delay: TimeInterval = 0)
    {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn, animations: {
            self.shineLabel.alpha = 0.0
        }, completion: nil)
    }
    
    func animateTextChange(_ text: String?, completion: (()->Void)?)
    {
        shineLabel.alpha = 1.0
        queuedText = text
        queuedCompletion = completion
        if !shineLabel.isShining {
            if shineLabel.isVisible {
                shineLabel.fade {
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
    
    // MARK:  Helpers
    
    @discardableResult func loadWallpaperRefs(songId: String) -> [ImageRef] {
        if let wallpaperRefs = diskCatalog.loadWallpaper(name: songId) {
            wallpaperImagesDataSource = ImageCellDataSource(view: wallpaperCollectionView, imageRefs: wallpaperRefs)
            return wallpaperRefs
        } else {
            let randomNumber = Int.random(in: 0..<defaultAlbumRefList.count)
            let image1 = defaultAlbumRefList[randomNumber]
            let image2 = defaultAlbumRefList[(randomNumber + Int.random(in: 1..<(defaultAlbumRefList.count-1))) % defaultAlbumRefList.count]
            let imageRefs = [image1, image2]
            wallpaperImagesDataSource = ImageCellDataSource(view: wallpaperCollectionView, imageRefs: imageRefs)
            diskCatalog.saveWallpaper(name: songId, imageRefs: imageRefs)
            return imageRefs
        }
    }
    
    // MARK:  Actions
    
    @IBAction func sliderValueChanged(_ sender: Any) {
        switch(slider.roundedValue) {
        case 1.0:
            detectStatus = .Stopped
            micIconView.hide()
            micOffIconView.hide()
            addPhotoIconView.hide()
            clearIconView.hide()
            detectLabel.fadeOut()
            photosLabel.fadeOut()
            cancelLabel.fadeOut()
            blurOutPhotoView()
            enterHomeScreen()
            fadeOutSlider(true)
            break
        case 0:
            detectStatus = .Verifying
            detectStatusClosure()
            micIconView.show(activate: true)
            shineLabel.shine()
            micOffIconView.show()
            addPhotoIconView.hide()
            clearIconView.hide()
            detectLabel.fadeIn(toAlpha: 1)
            cancelLabel.fadeIn(toAlpha: 0.5)
            photosLabel.fadeOut()
            blurOutPhotoView()
            enterDetectView(detectOn: true)
            exitLyricView()
            fadeOutSlider(false)
            break
        case 2.0:
            detectStatus = .Stopped
            micIconView.hide()
            micOffIconView.hide()
            addPhotoIconView.show(activate: true)
            clearIconView.show()
            photosLabel.fadeIn(toAlpha: 1)
            cancelLabel.fadeIn(toAlpha: 0.5)
            detectLabel.fadeOut()
            blurInPhotoView()
            exitDetectView()
            exitLyricView()
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
