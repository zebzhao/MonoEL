//
//  ViewController.swift
//  Nebula
//
//  Created by Simon Gladman on 08/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

//
// Based on http://glslsandbox.com/e#31308.0

import UIKit

class ViewController: UIViewController
{
    @IBOutlet var imageViewContainer: UIView!
    @IBOutlet var imageView: MetalImageView!
    @IBOutlet var bottomImageView: MetalImageView!
    
    let scaleFactor: CGFloat = 6
    var time: CGFloat = 1
    var resolution = CIVector(x: 0, y: 0)
    var bottomResolution = CIVector(x: 0, y: 0)
    var touchPosition = CIVector(x: 0, y: 0)
    var pitchRange1 = CIVector(x: 0, y: 0, z: 0, w: 0)
    var pitchRange2 = CIVector(x: 0, y: 0, z: 0, w: 0)
    var pitchRange3 = CIVector(x: 0, y: 0, z: 0, w: 0)
    
    let recordAudio = RecordAudio()
    
    lazy var cloudsKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "cloudsShader", fromMetalLibraryData: data)
            return kernel
    }()
    
    lazy var wheelKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "wheelShader", fromMetalLibraryData: data)
            return kernel
    }()
    
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        imageViewContainer.transform = CGAffineTransform.identity.scaledBy(x: scaleFactor, y: scaleFactor)

        let displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        
        recordAudio.startRecording()
    }
    
    // MARK: Step
    
    @objc func step()
    {
        time += 0.001
        
        let cArguments = [time, touchPosition, resolution, 1.0, 1.0, 1.0, 1.0] as [Any]
        let image = cloudsKernel.apply(extent: imageViewContainer.bounds, arguments: cArguments)
        let pitchBuffer = recordAudio.pitchBuffer
        
        pitchRange1 = CIVector(x: pitchBuffer[0], y: pitchBuffer[1], z: pitchBuffer[2], w: pitchBuffer[3])
        pitchRange2 = CIVector(x: pitchBuffer[4], y: pitchBuffer[5], z: pitchBuffer[6], w: pitchBuffer[7])
        pitchRange3 = CIVector(x: pitchBuffer[8], y: pitchBuffer[9], z: pitchBuffer[10], w: pitchBuffer[11])
        
        let wArguments = [time, bottomResolution, pitchRange1, pitchRange2, pitchRange3] as [Any]
        let wImage = wheelKernel.apply(extent: bottomImageView.bounds, arguments: wArguments)
        
        imageView.image = image
        bottomImageView.image = wImage
    }
    
    override func viewDidLayoutSubviews()
    {
        imageViewContainer.bounds = CGRect.init(x: 0.0, y: 24.0/scaleFactor, width: ceil(view.bounds.width/scaleFactor)+1.0, height: (view.bounds.height - 128.0)/scaleFactor)
        imageViewContainer.frame = CGRect.init(x: 0.0, y: 24.0, width: view.bounds.width+scaleFactor, height: view.bounds.height - 128.0)
        bottomImageView.bounds = CGRect.init(x: 0.0, y: 0.0, width: view.bounds.width, height: 128.0)
        bottomImageView.frame = CGRect.init(x: 0.0, y: view.bounds.height - 128.0, width: view.bounds.width, height: 128.0)
        resolution = CIVector(x: imageViewContainer.bounds.width, y: imageViewContainer.bounds.height)
        bottomResolution = CIVector(x: bottomImageView.bounds.width, y: bottomImageView.bounds.height)
    }
}
