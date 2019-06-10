//
//  ViewController.swift
//  Nebula
//
//  Created by Simon Gladman on 08/03/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

//
// Based on http://glslsandbox.com/e#31308.0

import Metal
import MetalKit
import MetalPerformanceShaders
import UIKit

class ViewController: UIViewController
{
    let scaleFactor: CGFloat = 6
    var time: CGFloat = 1
    var resolution = CIVector(x: 0, y: 0)
    var touchPosition = CIVector(x: 0, y: 0)
    
    let imageView = MetalImageView()
    let recordAudio = RecordAudio()
    
    lazy var nebulaKernel: CIColorKernel =
        {
            let url = Bundle.main.url(forResource: "default", withExtension: "metallib")!
            let data = try! Data(contentsOf: url)
            let kernel = try! CIColorKernel(functionName: "nebulaKernel", fromMetalLibraryData: data)
            return kernel
    }()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        viewDidLayoutSubviews()
        
        view.transform = CGAffineTransform.identity.scaledBy(x: scaleFactor, y: scaleFactor)
        view.addSubview(imageView)
        
        let displayLink = CADisplayLink(target: self, selector: #selector(step))
//        displayLink.preferredFramesPerSecond = 30
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        
        recordAudio.startRecording()
    }
    
    // MARK: Step
    
    @objc func step()
    {
        time += 0.01
        
        let arguments = [time, touchPosition, resolution, 1.0, 1.0, 1.0, 1.0] as [Any]
        
        let image = nebulaKernel.apply(extent: view.bounds, arguments: arguments)
        
        imageView.image = image
    }
    
    override func viewDidLayoutSubviews()
    {
        resolution = CIVector(x: view.frame.width/scaleFactor, y: view.frame.height/scaleFactor)
        imageView.frame = view.bounds
    }
}


// -----

class MetalImageView: MTKView
{
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    var commandQueue: MTLCommandQueue
    var ciContext: CIContext
    
    override init(frame frameRect: CGRect, device: MTLDevice?)
    {
        let metalDevice: MTLDevice = device ?? MTLCreateSystemDefaultDevice()!
        
        commandQueue = metalDevice.makeCommandQueue()!
        ciContext = CIContext(
            mtlDevice: metalDevice,
            options: [CIContextOption.outputColorSpace: NSNull(),
                      CIContextOption.workingColorSpace: NSNull()])
        
        super.init(frame: frameRect,
                   device: metalDevice)
        
        if super.device == nil
        {
            fatalError("Device doesn't support Metal")
        }
        
        framebufferOnly = false
    }
    
    required init(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// The image to display
    var image: CIImage?
    {
        didSet
        {
            renderImage()
        }
    }
    
    func renderImage()
    {
        guard let
            image = image,
            let targetTexture = currentDrawable?.texture else
        {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        let bounds = CGRect(origin: CGPoint.zero, size: drawableSize)
        
        let originX = image.extent.origin.x
        let originY = image.extent.origin.y
        
        let scaleX = drawableSize.width / image.extent.width
        let scaleY = drawableSize.height / image.extent.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = image
            .transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        ciContext.render(scaledImage,
                         to: targetTexture,
                         commandBuffer: commandBuffer,
                         bounds: bounds,
                         colorSpace: colorSpace)
        
        commandBuffer.present(currentDrawable!)
        
        commandBuffer.commit()
    }
}
