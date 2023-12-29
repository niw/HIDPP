//
//  Dictionary.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/29/23.
//

import Foundation

extension Dictionary {
    mutating func value(forKey key: Key, default block: (Key) -> Value) -> Value {
        if let value = self[key] {
            return value
        } else {
            let value = block(key)
            self[key] = value
            return value
        }
    }
}
