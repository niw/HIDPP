//
//  Queue.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/25/23.
//

import Foundation

struct Queue<Element: Equatable & Sendable>: Sendable {
    private var elements: [Element] = []

    mutating func enqueue(_ element: Element) {
        elements.append(element)
    }

    mutating func dequeue() -> Element? {
        if elements.isEmpty {
            return nil
        } else {
            return elements.removeFirst()
        }
    }

    mutating func remove(_ element: Element) {
        if let index = elements.firstIndex(of: element) {
            elements.remove(at: index)
        }
    }
}
