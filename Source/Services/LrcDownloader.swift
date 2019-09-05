//
//  LrcDownloader.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/2/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire


class LrcDownloader {
    
    func getLyricsByTitle(_ Title: String, Artist: String?, duration: Double?, complete: @escaping (Candidate?, String?)->Void) {
        let songDuration = Int((duration ?? 0)*1000)
        let parameters: Parameters = ["ver": "1",
                                      "man": "yes",
                                      "client": "pc",
                                      "keyword": Title.appending(Artist ?? ""),
                                      "duration": songDuration]
        AF.request("http://lyrics.kugou.com/search", parameters: parameters)
            .validate(statusCode: [200])
            .validate(contentType: ["application/json"])
            .responseJSON { resp in
                switch resp.result {
                case .success:
                    let searchResult = resp.value as! SearchResult
                    print(searchResult)
                    if searchResult.candidates.count <= 0 {
                        complete(nil, nil)
                    } else {
                        var minInterval = songDuration
                        var bestCandidate: Candidate?
                        for candidate in searchResult.candidates {
                            if abs(candidate.duration - songDuration) < minInterval {
                                minInterval = abs(candidate.duration - songDuration)
                                bestCandidate = candidate
                            }
                        }
                        if let candidate = bestCandidate {
                            self.getLyricsByID(candidate.id, accessKey: candidate.accesskey, complete: { lyrics in
                                if let lyrics = lyrics {
                                    complete(candidate, lyrics)
                                } else {
                                    complete(nil, nil)
                                }
                            })
                        } else {
                            complete(nil, nil)
                        }
                    }
                case let .failure(error):
                    complete(nil, nil)
                    print(error)
                }
            }
    }
    
    func getLyricsByID(_ ID: String, accessKey: String, complete: @escaping (String?)->Void) {
        let parameters: Parameters = ["ver": "1",
                                      "man": "yes",
                                      "client": "pc",
                                      "id": ID,
                                      "accesskey": accessKey,
                                      "fmt": "lrc",
                                      "charset": "utf8"]
        AF.request("http://lyrics.kugou.com/download", parameters: parameters)
            .validate(statusCode: [200])
            .validate(contentType: ["application/json"])
            .responseJSON { resp in
                switch resp.result {
                case .success:
                    let lyricsResult = resp.value as! LyricsResult
                    if lyricsResult.content.count <= 0 {
                        complete("")
                    } else {
                        if let lrcContent = Data(base64Encoded: lyricsResult.content),
                            let lyrics = String(data: lrcContent, encoding: .utf8) {
                            complete(lyrics)
                        } else {
                            complete("")
                        }
                    }
                case let .failure(error):
                    complete(nil)
                    print(error)
                }
        }
    }
}

struct SearchResult {
    let keyword: String
    let proposal: String
    let candidates: [Candidate]
}

struct Candidate {
    let song: String
    let singer: String
    let id: String
    let accesskey: String
    let duration: Int
}

struct LyricsResult {
    let fmt: String
    let charset: String
    let content: String
}
