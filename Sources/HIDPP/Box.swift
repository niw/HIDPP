//
//  Box.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/21/23.
//

import Foundation

final class Box<Value: Sendable>: Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
