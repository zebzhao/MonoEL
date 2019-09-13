//
//  GecimiRelaxSource.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/12/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire

class GecimiRelaxSource: LrcSource {
    override func searchUrl(song: String?, singer: String?, durationInMs: Int?) -> String {
        return "http://geci.me/api/lyric/\(song?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")/"
    }
    
    override func searchParameters(song: String?, singer: String?, durationInMs: Int?) -> Parameters? {
        return nil
    }
    
    override func lyricUrl(bestCandidate: [String : Any]) -> String? {
        return bestCandidate["lrc"] as? String
    }
    
    override func lyricParameters(bestCandidate: [String : Any]) -> Parameters? {
        return nil
    }
    
    override func getBestCandidate(_ searchResult: [String : Any]) -> [String : Any]? {
        return (searchResult["result"] as? [Any?] ?? [nil])[0] as? [String : Any]
    }
}
