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

    let scaleFactor: CGFloat = 6
    var time: CGFloat = 1
    var resolution = CIVector(x: 0, y: 0)
    var touchPosition = CIVector(x: 0, y: 0)
    
    let recordAudio = RecordAudio()
    
    lazy var nebulaKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "nebulaKernel", fromMetalLibraryData: data)
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
        time += 0.0025
        
        let arguments = [time, touchPosition, resolution, 1.0, 1.0, 1.0, 1.0] as [Any]
        
        let image = nebulaKernel.apply(extent: imageViewContainer.bounds, arguments: arguments)
        
        imageView.image = image
    }
    
    override func viewDidLayoutSubviews()
    {
        imageViewContainer.bounds = CGRect.init(x: 0, y: 0, width: ceil(view.bounds.width/scaleFactor)+1, height: (view.bounds.height - 96)/scaleFactor)
        imageViewContainer.frame = CGRect.init(x: 0, y: 0, width: view.bounds.width+scaleFactor, height: view.bounds.height - 96)
        resolution = CIVector(x: imageViewContainer.bounds.width, y: imageView.bounds.height)
    }
}
