//
//  ViewController.swift
//  Nebula
//
//  Created by Simon Gladman on 08/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
    
    @IBOutlet var imageViewContainer: UIView!
    @IBOutlet var imageView: MetalImageView!
    @IBOutlet var slider: VSSlider!
    @IBOutlet var detectLabel: UILabel!
    @IBOutlet var photosLabel: UILabel!
    @IBOutlet var cancelLabel: UILabel!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var albumCollectionView: DraggableCollectionView!
    @IBOutlet var albumCollectionViewContainer: UIView!
    @IBOutlet var photoView: UIView!
    
    let recordAudio = RecordAudio()
    let blurEffect = UIBlurEffect(style: .dark)
    let scaleFactor: CGFloat = 4
    
    var albumImagesDataSource: DraggableCollectionViewDataSource!
    var micIconView: BlurIconView!
    var micOffIconView: BlurIconView!
    var addPhotoIconView: BlurIconView!
    var clearIconView: BlurIconView!
    
    var time: Float = 1
    var resolution = CIVector(x: 0, y: 0)
    
    lazy var defaultKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "mainImage", fromMetalLibraryData: data)
            return kernel
    }()
    
//    override var prefersStatusBarHidden: Bool {
//        get {
//            return true
//        }
//    }
    
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
    
    override func viewDidLayoutSubviews()
    {
        imageViewContainer.bounds = CGRect.init(x: 0.0, y: 0.0, width: ceil(view.bounds.width/scaleFactor), height: ceil(view.bounds.height/scaleFactor))
        imageViewContainer.frame = CGRect.init(x: 0.0, y: 0.0, width: view.bounds.width, height: view.bounds.height)
        resolution = CIVector(x: imageViewContainer.bounds.width, y: imageViewContainer.bounds.height)
    }
    
    func setUpAlbum()
    {
        let bounds = albumCollectionViewContainer.bounds
        let gradient = CAGradientLayer()
        gradient.frame = bounds;
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor];
        gradient.locations = [35.0/bounds.height, 80.0/bounds.height, 1.0 - 80.0/bounds.height, 1.0 - 35.0/bounds.height] as [NSNumber]
        albumCollectionViewContainer.layer.mask = gradient
        
        albumImagesDataSource = DraggableCollectionViewDataSource(view: albumCollectionView, imagePaths: ["Image", "Image", "Image", "Image", "Image", "Image", "Image", "Image"])
    }
    
    func setUpSlider()
    {
        let x = slider.frame.minX + 2
        let midX = slider.frame.midX - 36
        let maxX = slider.frame.maxX - 78
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
