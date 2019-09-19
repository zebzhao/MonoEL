//
//  GecimiRelaxSource.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/12/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire

class KugouSource: LrcSource {
    override func searchUrl(song: String?, singer: String?, durationInMs: Int?) -> String {
        return "http://mobilecdn.kugou.com/api/v3/search/song"
    }
    
    override func searchParameters(song: String?, singer: String?, durationInMs: Int?) -> Parameters? {
        return [
            "keyword":"\(song ?? "") \(singer ?? "")",
            "platform":"WebFilter",
            "format":"json",
            "page":1,
            "pagesize":1
        ]
    }
    
    override func searchHeaders(song: String?, singer: String?, durationInMs: Int?) -> HTTPHeaders? {
        return HTTPHeaders(["Referer": "http://m.kugou.com"])
    }
    
    override func lyricUrl(bestCandidate: [String : Any]) -> String? {
        return "http://m.kugou.com/app/i/krc.php"
    }
    
    override func lyricHeaders(bestCandidate: [String : Any]) -> HTTPHeaders? {
        return HTTPHeaders(["Referer": "http://m.kugou.com/play/info/\(bestCandidate["hash"] ?? "")",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X] AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1"])
    }
    
    override func lyricParameters(bestCandidate: [String : Any]) -> Parameters? {
        return [
            "cmd": 100,
            "timelength": 999999,
            "hash": bestCandidate["hash"] ?? ""
        ]
    }
    
    override func getBestCandidate(_ searchResult: [String : Any]) -> [String : Any]? {
        let list = (searchResult as NSDictionary).value(forKeyPath: "data.info")
        return (list as? [Any?] ?? [nil])[0] as? [String : Any]
    }
}
