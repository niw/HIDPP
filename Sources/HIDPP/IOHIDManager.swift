//
//  IOHIDManager.swift
//  HIDPP
//
//  Created by Yoshimasa Niwa on 12/20/23.
//

import Foundation
import IOKit
import IOKit.hid

// TODO: This is fine.
extension IOHIDManager: @unchecked Sendable {
}

extension IOHIDManager {
    static func create(options: IOHIDManagerOptions = []) -> IOHIDManager {
        IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(options.rawValue))
    }

    func schedule(with runloop: RunLoop, mode: RunLoop.Mode) {
        IOHIDManagerScheduleWithRunLoop(self, runloop.getCFRunLoop(), mode.rawValue as CFString)
    }

    func unschedule(from runloop: RunLoop, mode: RunLoop.Mode) {
        IOHIDManagerUnscheduleFromRunLoop(self, runloop.getCFRunLoop(), mode.rawValue as CFString)
    }

    @discardableResult
    func open(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) -> IOReturn {
        IOHIDManagerOpen(self, options)
    }

    @discardableResult
    func close(options: IOOptionBits = IOOptionBits(kIOHIDOptionsTypeNone)) -> IOReturn {
        IOHIDManagerClose(self, options)
    }

    func setDeviceMatching(_ matching: [String : Any]) {
        IOHIDManagerSetDeviceMatching(self, matching as CFDictionary)
    }

    func setDeviceMatchingCallback(_ callback: IOHIDDeviceCallback?, context: UnsafeMutableRawPointer? = nil) {
        IOHIDManagerRegisterDeviceMatchingCallback(self, callback, context)
    }

    func setDeviceRemovalCallback(_ callback: IOHIDDeviceCallback?, context: UnsafeMutableRawPointer? = nil) {
        IOHIDManagerRegisterDeviceRemovalCallback(self, callback, context)
    }
}
