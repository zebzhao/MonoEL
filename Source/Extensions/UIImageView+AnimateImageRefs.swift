//
//  UIImageView+animate.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/21/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import UIKit
import MobileCoreServices

final class ImageRef: NSObject, Codable, NSItemProviderReading, NSItemProviderWriting {
    var path : String
    var durationInSeconds: Float?
    
    init(_ path: String) {
        self.path = path
    }
    
    init(path: String, durationInSeconds: Float) {
        self.path = path
        self.durationInSeconds = durationInSeconds
    }
    
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [(kUTTypeData) as String]
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> ImageRef {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ImageRef.self, from: data)
        } catch {
            fatalError("Err")
        }
    }
    
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [(kUTTypeData) as String]
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        let progress = Progress(totalUnitCount: 100)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            _ = String(data: data, encoding: String.Encoding.utf8)
            progress.completedUnitCount = 100
            completionHandler(data, nil)
        } catch {
            completionHandler(nil, error)
        }
        
        return progress
    }
}


extension UIImage {
    static func loadImageRef(imageRef: ImageRef?) -> UIImage? {
        if let imageRef=imageRef {
            if imageRef.path.starts(with: "Images/") {
                return UIImage(contentsOfFile: URL.urlInDocumentsDirectory(with: imageRef.path).path)
            } else {
                return UIImage(named: "\(imageRef.path)")
            }
        } else {
            return nil
        }
    }
}

extension UIImageView {
    func animateImageRefs(next: @escaping (() -> ImageRef?), nextImage: UIImage? = nil, nextImageRef: ImageRef? = nil) {
        self.layer.removeAllAnimations()
        let imageRef = nextImageRef ?? next()
        let image = nextImage ?? UIImage.loadImageRef(imageRef: imageRef)
        let duration = TimeInterval(imageRef?.durationInSeconds ?? (imageRef != nil ? 20.0 : 5.0)) - 2.0
        UIView.transition(with: self, duration: 2.0, options: .transitionCrossDissolve, animations: {
            self.image = image
        }, completion: { value in
            let nextImageRef = next()
            let nextImage = UIImage.loadImageRef(imageRef: nextImageRef)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.animateImageRefs(next: next, nextImage: nextImage, nextImageRef: nextImageRef)
            }
        })
    }
}
