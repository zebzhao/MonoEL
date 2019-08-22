//
//  URL+UrlInDocumentsDirectory.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/21/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation

extension URL {
    static var documentsDirectory: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }
    
    static func urlInDocumentsDirectory(with filename: String) -> URL {
        return URL(fileURLWithPath: documentsDirectory).appendingPathComponent(filename)
    }
}
