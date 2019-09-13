//
//  MiguSource.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/9/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire

class MiguSource: LrcSource {
    override func searchUrl(song: String?, singer: String?, durationInMs: Int?) -> String {
        return "http://pd.musicapp.migu.cn/MIGUM2.0/v1.0/content/search_all.do"
    }
    
    override func searchParameters(song: String?, singer: String?, durationInMs: Int?) -> Parameters? {
        return [
            "ua":"Android_migu",
            "version":"5.0.1",
            "text":"\(song ?? "") \(singer ?? "")",
            "pageNo":1,
            "pageSize":1,
            "searchSwitch": "{\"song\":1,\"album\":0,\"singer\":0,\"tagSong\":0,\"mvSong\":0,\"songlist\":0,\"bestShow\":1}"
        ]
    }
    
    override func lyricUrl(bestCandidate: [String : Any]) -> String? {
        if let lyricUrl = bestCandidate["lyricUrl"] as? String {
            return lyricUrl.replacingOccurrences(of: "https://", with: "http://")
        } else {
            return nil
        }
    }
    
    override func lyricParameters(bestCandidate: [String : Any]) -> Parameters? {
        return nil
    }
    
    override func getBestCandidate(_ searchResult: [String : Any]) -> [String : Any]? {
        return ((searchResult["songResultData"] as? [String : Any] ?? [:])["result"] as? [Any?] ?? [nil])[0] as? [String : Any]
    }
}
