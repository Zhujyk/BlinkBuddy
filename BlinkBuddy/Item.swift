//
//  Item.swift
//  BlinkBuddy
//
//  Created by Zhu on 15/04/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
