//
//  UIImage+FixOrientation.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/22/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    func fixOrientation() -> UIImage {
        if (self.imageOrientation == .up) {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        self.draw(in: rect)
        
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return normalizedImage
    }
}
