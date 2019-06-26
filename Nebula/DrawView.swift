import UIKit

class DrawView <T:Drawable>: UIView {
    typealias DrawableType = T
    let drawable = DrawableType()
    
    override func draw(_ rect: CGRect) {
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            drawable.draw(renderer: context)
            context.restoreGState()
        }
    }
    
    init() {
        super.init(frame: CGRect.zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
