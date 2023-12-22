//
//  Buffer.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/21/23.
//

import Foundation

class Buffer {
    let pointer: UnsafeMutableRawBufferPointer

    init(size: Int) {
        pointer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: 8)
    }

    deinit {
        pointer.deallocate()
    }
}
