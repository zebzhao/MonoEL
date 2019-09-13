//
//  LrcDownloader.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/2/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire


enum LrcLyricFormat {
    case text
    case json
}

class LrcSource {
    var lyricFormat: LrcLyricFormat { return .text }
    
    func searchUrl(song: String?, singer: String?, durationInMs: Int?) -> String {
        return ""
    }
    
    func searchParameters(song: String?, singer: String?, durationInMs: Int?) -> Parameters? {
        return nil
    }
    
    func lyricUrl(bestCandidate: [String: Any]) -> String? {
        return ""
    }
    
    func lyricParameters(bestCandidate: [String: Any]) -> Parameters? {
        return Parameters()
    }
    
    func getBestCandidate(_ searchResult: [String: Any]) -> [String: Any]? {
        return nil
    }
    
    func getLyrics(_ lyricResult: [String: Any]) -> String? {
        return nil
    }
    
    func request(song: String?, singer: String?, durationInMs: Int?, complete: @escaping (Candidate?)->Void) {
        AF.request(searchUrl(song: song, singer: singer, durationInMs: durationInMs), parameters: searchParameters(song: song, singer: singer, durationInMs: durationInMs))
            .validate(statusCode: [200])
            .responseJSON { resp in
                switch resp.result {
                case .success:
                    if let json = resp.value as? [String: Any],
                        let bestCandidate = self.getBestCandidate(json),
                        let lyricUrl = self.lyricUrl(bestCandidate: bestCandidate) {
                        print("LU", lyricUrl)
                        let lyricRequest = AF.request(lyricUrl, parameters: self.lyricParameters(bestCandidate: bestCandidate))
                            .validate(statusCode: [200])
                        
                        switch self.lyricFormat {
                        case .json:
                            lyricRequest.responseJSON { resp in
                                if let json = resp.value as? [String: Any],
                                    let lyrics = self.getLyrics(json) {
                                    complete(Candidate(song: song, singer: singer, duration: durationInMs, lyrics: lyrics))
                                } else {
                                    complete(nil)
                                }
                            }
                        case .text:
                            lyricRequest.responseString { resp in
                                if let lyrics = resp.value {
                                    complete(Candidate(song: song, singer: singer, duration: durationInMs, lyrics: lyrics))
                                } else {
                                    complete(nil)
                                }
                            }
                        }
                    } else {
                        complete(nil)
                    }
                case let .failure(error):
                    complete(nil)
                    print(error)
                }
        }
    }
}


class LrcDownloader {
    let sources: [LrcSource]
    
    init(_ sources: [LrcSource]) {
        self.sources = sources
    }
    
    func getLyrics(song: String?, singer: String?, durationInMs: Int?, complete: @escaping (Candidate?)->Void, srcIndex: Int = 0) {
        if srcIndex < self.sources.count {
            sources[srcIndex].request(song: song, singer: singer, durationInMs: durationInMs) { candidate in
                if candidate == nil {
                    self.getLyrics(song: song, singer: singer, durationInMs: durationInMs, complete: complete, srcIndex: srcIndex+1)
                } else {
                    complete(candidate)
                }
            }
        } else {
            complete(nil)
        }
    }
}

struct Candidate: Codable {
    let song: String?
    let singer: String?
    let duration: Int?
    let lyrics: String?
}
