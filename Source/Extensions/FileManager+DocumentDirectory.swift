// https://stackoverflow.com/questions/27721418/getting-list-of-files-in-documents-folder

import Foundation

extension FileManager {
    func urls(for directory: String, skipsHiddenFiles: Bool = true ) -> [URL]? {
        let documentsURL = urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryPath = documentsURL.appendingPathComponent(directory)
        do
        {
            try FileManager.default.createDirectory(atPath: directoryPath.path, withIntermediateDirectories: true, attributes: nil)
        }
        catch let error as NSError
        {
            NSLog("Unable to create directory \(error.debugDescription)")
        }
        let fileURLs = try? contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: skipsHiddenFiles ? .skipsHiddenFiles : [] )
        return fileURLs
    }
}
