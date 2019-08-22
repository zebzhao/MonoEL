//
//  DiskCatalog.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/6/19.
//

import Foundation
import Disk

class DiskCatalog {
    var controller: ViewController
    
    init(controller: ViewController) {
        self.controller = controller
    }
    
    func saveAlbum(imageRefs: [ImageRef]) -> Bool {
        do {
            try Disk.save(imageRefs, to: .documents, as: "album.json")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to save album.", error: error)
            print(error.localizedDescription)
            return false
        }
    }
    
    func loadAlbum() -> [ImageRef]? {
        return try? Disk.retrieve("album.json", from: .documents, as: [ImageRef].self)
    }
    
    func saveWallpaper(name: String, imageRefs: [ImageRef]) -> Bool {
        do {
            try Disk.save(imageRefs, to: .documents, as: "Wallpapers/\(name)")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to save wallpaper.", error: error)
            print(error.localizedDescription)
            return false
        }
    }
    
    func loadWallpaper(name: String) -> [ImageRef]? {
        return try? Disk.retrieve("Wallpapers/\(name)", from: .documents, as: [ImageRef].self)
    }
    
    func saveImage(name: String, image: UIImage) -> Bool {
        do {
            try Disk.save(image, to: .documents, as: "Images/\(name)")
            return true
        } catch let error as NSError {
            print(error.localizedDescription)
            showAlert(title: "Fail to upload image.", error: error)
            return false
        }
    }
    
    func existsImage(name: String) -> Bool {
        return Disk.exists("Images/\(name)", in: .documents)
    }
    
    func deleteImage(relativePath: String) -> Bool {
        do {
            try Disk.remove(relativePath, from: .documents)
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to delete image.", error: error)
            return false
        }
    }
    
    func listFiles(at: String) -> [URL]? {
        return try? FileManager.default.contentsOfDirectory(at: URL.urlInDocumentsDirectory(with: at), includingPropertiesForKeys: nil)
    }
    
    func showAlert(title: String, error: NSError) {
        let alertController = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        self.controller.present(alertController, animated: true, completion: nil)
    }
}
