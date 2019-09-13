//
//  TcSource.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/7/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire

class NetEaseSource: LrcSource {
    override var lyricFormat: LrcLyricFormat { return .json }
    override func searchUrl(song: String?, singer: String?, durationInMs: Int?) -> String {
        return "https://music.163.com/api/cloudsearch/pc"
    }
    
    override func searchParameters(song: String?, singer: String?, durationInMs: Int?) -> Parameters {
        return [
            "s": "\(song ?? "") \(singer ?? "")",
            "type": 1,
            "limit": 1,
            "total": "true",
            "offset": 0
        ]
    }
    
    override func lyricUrl(bestCandidate: [String : Any]) -> String? {
        return "https://api.imjad.cn/cloudmusic"
    }
    
    override func lyricParameters(bestCandidate: [String : Any]) -> Parameters? {
        return [
            "type": "lyric",
            "id": bestCandidate["id"]!
        ]
    }
    
    override func getBestCandidate(_ searchResult: [String : Any]) -> [String : Any]? {
        return ((searchResult["result"] as? [String : Any] ?? [:])["songs"] as? [Any?] ?? [nil])[0] as? [String : Any]
    }
    
    override func getLyrics(_ lyricResult: [String : Any]) -> String? {
        return (lyricResult["lrc"] as? [String : Any] ?? [:])["lyric"] as? String
    }
}
