//
//  Array+RandomPick.swift
//  Nebula
//
//  Created by Zeb Zhao on 9/15/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//  From: https://stackoverflow.com/questions/27259332/get-random-elements-from-array-in-swift/50853765

import Foundation

extension Array {
    /// Picks `n` random elements (partial Fisher-Yates shuffle approach)
    subscript (randomPick n: Int) -> [Element] {
        var copy = self
        for i in stride(from: count - 1, to: count - n - 1, by: -1) {
            copy.swapAt(i, Int(arc4random_uniform(UInt32(i + 1))))
        }
        return Array(copy.suffix(n))
    }
}
