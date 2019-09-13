//
//  DiskCatalog.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/6/19.
//

import Foundation
import Disk

class DiskCatalog {
    let simulateFreshInstall = true
    weak var controller: ViewController?
    
    init(controller: ViewController) {
        self.controller = controller
    }
    
    @discardableResult func saveAlbum(imageRefs: [ImageRef]) -> Bool {
        do {
            try Disk.save(imageRefs, to: .documents, as: "album.json")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to save album.", error: error)
            return false
        }
    }
    
    func loadAlbum() -> [ImageRef]? {
        return simulateFreshInstall ? nil : try? Disk.retrieve("album.json", from: .documents, as: [ImageRef].self)
    }
    
    @discardableResult func saveWallpaper(name: String, imageRefs: [ImageRef]) -> Bool {
        do {
            try Disk.save(imageRefs, to: .documents, as: "Wallpapers/\(name)")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to save wallpaper.", error: error)
            return false
        }
    }
    
    func loadWallpaper(name: String) -> [ImageRef]? {
        return simulateFreshInstall ? nil : try? Disk.retrieve("Wallpapers/\(name)", from: .documents, as: [ImageRef].self)
    }
    
    @discardableResult func saveImage(name: String, image: UIImage) -> Bool {
        do {
            try Disk.save(image, to: .documents, as: "Images/\(name)")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to upload image.", error: error)
            return false
        }
    }
    
    func existsImage(name: String) -> Bool {
        return simulateFreshInstall ? false : Disk.exists("Images/\(name)", in: .documents)
    }
    
    @discardableResult func deleteImage(relativePath: String) -> Bool {
        do {
            if !relativePath.starts(with: "WP_") {
                try Disk.remove(relativePath, from: .documents)
            }
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to delete image.", error: error)
            return false
        }
    }
    
    func loadCandidate(song: String?, singer: String?, durationInMs: Int) -> Candidate? {
        let songStr = song ?? ""
        let singerStr = singer ?? ""
        let id = "\(songStr) ~ \(singerStr) ~ \(durationInMs).lrc"
        return simulateFreshInstall ? nil : try? Disk.retrieve("Candidates/\(id)", from: .caches, as: Candidate.self)
    }
    
    @discardableResult func saveCandidate(song: String?, singer: String?, durationInMs: Int, candidate: Candidate) -> Bool {
        let songStr = song ?? ""
        let singerStr = singer ?? ""
        let id = "\(songStr) ~ \(singerStr) ~ \(durationInMs).lrc"
        do {
            try Disk.save(candidate, to: .caches, as: "Candidates/\(id)")
            return true
        } catch let error as NSError {
            showAlert(title: "Fail to save lyrics.", error: error)
            return false
        }
    }
    
    func listFiles(at: String) -> [URL]? {
        return simulateFreshInstall ? nil : try? FileManager.default.contentsOfDirectory(at: URL.urlInDocumentsDirectory(with: at), includingPropertiesForKeys: nil)
    }
    
    func showAlert(title: String, error: NSError) {
        let alertController = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        self.controller!.present(alertController, animated: true, completion: nil)
        print(error.localizedDescription)
    }
}
