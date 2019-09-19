//
//  LrcDownloader.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/2/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation
import Alamofire


struct LrcDownloadProgress {
    let progress: Float
    let errors: Int
}

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
    
    func searchHeaders(song: String?, singer: String?, durationInMs: Int?) -> HTTPHeaders? {
        return nil
    }
    
    func lyricUrl(bestCandidate: [String: Any]) -> String? {
        return ""
    }
    
    func lyricHeaders(bestCandidate: [String: Any]) -> HTTPHeaders? {
        return nil
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
    
    func request(song: String?, singer: String?, durationInMs: Int?, progress: @escaping (LrcDownloadProgress)->Void, complete: @escaping (Candidate?)->Void) {
        AF.request(searchUrl(song: song, singer: singer, durationInMs: durationInMs),
                   parameters: searchParameters(song: song, singer: singer, durationInMs: durationInMs),
                   headers: searchHeaders(song: song, singer: singer, durationInMs: durationInMs))
            .validate(statusCode: [200])
            .responseJSON { resp in
                switch resp.result {
                case .success:
                    if let json = resp.value as? [String: Any],
                        let bestCandidate = self.getBestCandidate(json),
                        let lyricUrl = self.lyricUrl(bestCandidate: bestCandidate) {
                        progress(LrcDownloadProgress(progress: 0.5, errors: 0))
                        let lyricRequest = AF.request(
                            lyricUrl,
                            parameters: self.lyricParameters(bestCandidate: bestCandidate),
                            headers: self.lyricHeaders(bestCandidate: bestCandidate))
                            .validate(statusCode: [200])
                        switch self.lyricFormat {
                        case .json:
                            lyricRequest.responseJSON { resp in
                                if let json = resp.value as? [String: Any],
                                    let lyrics = self.getLyrics(json) {
                                    progress(LrcDownloadProgress(progress: 1.0, errors: 0))
                                    complete(Candidate(song: song, singer: singer, duration: durationInMs, lyrics: lyrics))
                                } else {
                                    progress(LrcDownloadProgress(progress: 0.5, errors: 1))
                                    complete(nil)
                                }
                            }
                        case .text:
                            lyricRequest.responseString(encoding: .utf8) { resp in
                                if let lyrics = resp.value {
                                    progress(LrcDownloadProgress(progress: 1.0, errors: 0))
                                    complete(Candidate(song: song, singer: singer, duration: durationInMs, lyrics: lyrics))
                                } else {
                                    progress(LrcDownloadProgress(progress: 0.5, errors: 1))
                                    complete(nil)
                                }
                            }
                        }
                    } else {
                        complete(nil)
                        progress(LrcDownloadProgress(progress: 0, errors: 1))
                    }
                case let .failure(error):
                    complete(nil)
                    progress(LrcDownloadProgress(progress: 0, errors: 1))
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
    
    func getLyrics(song: String?, singer: String?, durationInMs: Int?, progress: @escaping (LrcDownloadProgress)->Void, complete: @escaping (Candidate?)->Void, srcIndex: Int = 0) {
        var totalErrors: Int = 0
        var totalProgress: Float = 0
        let totalSources = self.sources.count
        if srcIndex < totalSources {
            sources[srcIndex].request(song: song, singer: singer, durationInMs: durationInMs,
                                      progress: { progressData in
                                        totalErrors += progressData.errors
                                        if progressData.progress < 1 {
                                            totalProgress += progressData.progress/Float(totalSources)
                                        } else {
                                            totalProgress = 1
                                        }
                                        progress(LrcDownloadProgress(progress: totalProgress, errors: totalErrors))
            }) { candidate in
                if candidate == nil {
                    self.getLyrics(song: song, singer: singer, durationInMs: durationInMs, progress: progress, complete: complete, srcIndex: srcIndex+1)
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
