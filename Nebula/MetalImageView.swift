import Metal
import MetalKit

class MetalImageView: MTKView
{
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    static var commandQueue: MTLCommandQueue?
    
    static var ciContext: CIContext?
    
    required init(coder: NSCoder)
    {
        let metalDevice: MTLDevice = MTLCreateSystemDefaultDevice()!
        
        if MetalImageView.commandQueue == nil {
            MetalImageView.commandQueue = metalDevice.makeCommandQueue()
        }
        
        if MetalImageView.ciContext == nil {
            MetalImageView.ciContext = CIContext(
                mtlDevice: metalDevice,
                options: [CIContextOption.outputColorSpace: NSNull(),
                          CIContextOption.workingColorSpace: NSNull()])
        }
        
        super.init(coder: coder)
        
        self.device = metalDevice
        
        if super.device == nil
        {
            fatalError("Device doesn't support Metal")
        }
        
        framebufferOnly = false
    }
    
    /// The image to display
    var image: CIImage?
    {
        didSet
        {
            autoreleasepool {
                renderImage()
            }
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
        
        let commandBuffer = MetalImageView.commandQueue!.makeCommandBuffer()!
        
        let bounds = CGRect(origin: CGPoint.zero, size: drawableSize)
        
        let originX = image.extent.origin.x
        let originY = image.extent.origin.y
        
        let scaleX = drawableSize.width / image.extent.width
        let scaleY = drawableSize.height / image.extent.height
        let scale = min(scaleX, scaleY)
        
        let scaledImage = image
            .transformed(by: CGAffineTransform(translationX: -originX, y: -originY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        MetalImageView.ciContext!.render(scaledImage,
                         to: targetTexture,
                         commandBuffer: commandBuffer,
                         bounds: bounds,
                         colorSpace: colorSpace)
        
        commandBuffer.present(currentDrawable!)
        
        commandBuffer.commit()
    }
}
