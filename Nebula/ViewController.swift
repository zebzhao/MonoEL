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
    
    let scaleFactor: CGFloat = 4
    var time: CGFloat = 1
    var resolution = CIVector(x: 0, y: 0)
    
    let recordAudio = RecordAudio()
    
    lazy var defaultKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "mainImage", fromMetalLibraryData: data)
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
}
