//
//  Table.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/21/23.
//

import Foundation

struct Table<Key, Value> where Key: Hashable {
    private var factory: (Key) -> Value
    private var dictionary: [Key : Value] = [:]

    init(_ factory: @escaping (Key) -> Value) {
        self.factory = factory
    }

    mutating func reset() {
        dictionary.removeAll()
    }

    mutating func removeValue(forKey key: Key) {
        dictionary.removeValue(forKey: key)
    }

    mutating func value(forKey key: Key) -> Value {
        if let value = dictionary[key] {
            return value
        }
        let value = factory(key)
        dictionary[key] = value
        return value
    }
}
