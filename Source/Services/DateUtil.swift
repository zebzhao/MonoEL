//
//  DateUtil.swift
//  Nebula
//
//  Created by Zeb Zhao on 8/20/19.
//  Copyright © 2019 Zeb Zhao. All rights reserved.
//

import Foundation

class DateUtil
{
    static func nowAsString() -> String {
        let dateFormatter : DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh.mm.ss a"
        let date = Date()
        return dateFormatter.string(from: date)
    }
}
