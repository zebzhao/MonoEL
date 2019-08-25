//
//  AveragingBuffer.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/23/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation

class AveragingBuffer {
    var idx: Int = 0
    var buffer: [Float]
    var length: Int
    var average: Float
    var sum: Float
    var noAveragingAtStart: Bool
    
    init(length: Int = 5, repeating: Float = 0, noAveragingAtStart: Bool = true) {
        self.length = length
        self.buffer = [Float](repeating: repeating, count: length)
        self.sum = repeating*Float(length)
        self.average = repeating
        self.noAveragingAtStart = noAveragingAtStart
    }
    
    func update(value: Float) {
        buffer[idx % length] = value
        sum = (noAveragingAtStart && idx <= length ? buffer[0 ..< idx].reduce(0.0, +) : buffer.reduce(0.0, +))
        average = sum/Float(length)
        idx += 1
        if !noAveragingAtStart {
            idx = idx % length
        }
    }
}
